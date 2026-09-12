using System.Collections.Concurrent;
using System.Net.Http.Headers;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using IFX.Platform.Authentication.Contracts.V1;

namespace IFX.Platform.Authentication.Runtime;

public sealed class OidcProtocolService(IHttpClientFactory clients, ITokenValidationContract tokens, TimeProvider? clock = null) : IOidcProtocolContract
{
    private readonly TimeProvider _clock = clock ?? TimeProvider.System;
    private sealed record LoginTransaction(string Binding, string ClientFingerprint, string Verifier, string Nonce, DateTimeOffset ExpiresAt);
    private readonly ConcurrentDictionary<string, LoginTransaction> _transactions = new(StringComparer.Ordinal);

    public OidcAuthorizationResponse Begin(OidcClientOptions client, string browserBinding)
    {
        ValidateClient(client);
        if (browserBinding.Length < 32) throw new ArgumentException("Browser binding is required.");
        foreach (var entry in _transactions.Where(entry => entry.Value.ExpiresAt <= _clock.GetUtcNow()))
            _transactions.TryRemove(entry.Key, out _);
        if (_transactions.Count >= 10000) throw new InvalidOperationException("Login transaction capacity exceeded.");
        var state = RandomValue();
        var verifier = RandomValue();
        var nonce = RandomValue();
        if (!_transactions.TryAdd(state, new(browserBinding, Fingerprint(client), verifier, nonce,
            _clock.GetUtcNow().AddSeconds(Math.Clamp(client.StateLifetimeSeconds, 30, 600)))))
            throw new InvalidOperationException("Cannot allocate login transaction.");
        return new(Query(client.AuthorizationEndpoint, new()
        {
            ["response_type"] = "code", ["client_id"] = client.ClientId,
            ["redirect_uri"] = client.CallbackUrl, ["scope"] = string.Join(' ', client.Scopes.Distinct()),
            ["state"] = state, ["nonce"] = nonce, ["code_challenge_method"] = "S256",
            ["code_challenge"] = Encode(SHA256.HashData(Encoding.ASCII.GetBytes(verifier)))
        }), state);
    }

    public async Task<ProviderTokenResponse> RedeemAsync(OidcClientOptions client, string code, string state,
        string browserBinding, CancellationToken cancellationToken = default)
    {
        ValidateClient(client);
        // Atomic consumption also rejects simultaneous callbacks, including retries after failure.
        if (!_transactions.TryRemove(state, out var transaction) || transaction.ExpiresAt <= _clock.GetUtcNow() ||
            transaction.Binding != browserBinding || transaction.ClientFingerprint != Fingerprint(client) || string.IsNullOrWhiteSpace(code))
            return Failure("invalid_login_transaction");
        try
        {
            using var request = new HttpRequestMessage(HttpMethod.Post, client.TokenEndpoint);
            var fields = new Dictionary<string, string>
            {
                ["grant_type"] = "authorization_code", ["client_id"] = client.ClientId,
                ["code"] = code, ["redirect_uri"] = client.CallbackUrl, ["code_verifier"] = transaction.Verifier
            };
            if (!string.IsNullOrEmpty(client.ClientSecret)) fields["client_secret"] = client.ClientSecret;
            request.Content = new FormUrlEncodedContent(fields);
            using var response = await clients.CreateClient("Authentication.Oidc").SendAsync(request, cancellationToken);
            if (!response.IsSuccessStatusCode) return Failure("token_exchange_failed");
            using var document = await ReadDocument(response, cancellationToken);
            var root = document.RootElement;
            var idToken = ReadString(root, "id_token");
            var accessToken = ReadString(root, "access_token");
            if (string.IsNullOrWhiteSpace(idToken) || string.IsNullOrWhiteSpace(accessToken)) return Failure("invalid_token_response");
            var identity = await tokens.ValidateAsync(idToken,
                new(client.Issuer, client.Authority, [client.ClientId], client.AllowedAlgorithms, 60), transaction.Nonce, cancellationToken);
            if (!identity.IsValid) return Failure(identity.ReasonCode);
            // OIDC userinfo must belong to the identity that was just verified.
            var info = await GetUserInfoAsync(client.UserInfoEndpoint, accessToken, cancellationToken);
            if (info?.Subject != identity.Identity!.Subject) return Failure("userinfo_subject_mismatch");
            return new()
            {
                Success = true, AccessToken = accessToken, IdToken = idToken,
                RefreshToken = ReadString(root, "refresh_token"),
                ExpiresIn = root.TryGetProperty("expires_in", out var expiry) && expiry.TryGetInt32(out var seconds) ? seconds : 0,
                TokenType = ReadString(root, "token_type") ?? "Bearer",
                Issuer = identity.Identity.Issuer, Subject = identity.Identity.Subject
            };
        }
        catch (OperationCanceledException) when (cancellationToken.IsCancellationRequested) { throw; }
        catch (Exception) { return Failure("protocol_unavailable"); }
    }

    public async Task<OidcMetadataDto> DiscoverAsync(string trustedIssuer, CancellationToken cancellationToken = default)
    {
        RequireHttps(trustedIssuer);
        using var response = await clients.CreateClient("Authentication.Oidc").GetAsync(
            trustedIssuer.TrimEnd('/') + "/.well-known/openid-configuration", cancellationToken);
        response.EnsureSuccessStatusCode();
        using var document = await ReadDocument(response, cancellationToken);
        if (ReadString(document.RootElement, "issuer") != trustedIssuer) throw new InvalidOperationException("Discovery issuer mismatch.");
        var endpoint = ReadString(document.RootElement, "userinfo_endpoint");
        if (endpoint is not null) RequireHttps(endpoint);
        return new(trustedIssuer, endpoint);
    }

    public async Task<OidcUserInfoDto?> GetUserInfoAsync(string trustedEndpoint, string accessToken, CancellationToken cancellationToken = default)
    {
        RequireHttps(trustedEndpoint);
        using var request = new HttpRequestMessage(HttpMethod.Get, trustedEndpoint);
        request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", accessToken);
        using var response = await clients.CreateClient("Authentication.Oidc").SendAsync(request, cancellationToken);
        if (!response.IsSuccessStatusCode) return null;
        using var document = await ReadDocument(response, cancellationToken);
        var root = document.RootElement;
        var subject = ReadString(root, "sub");
        if (string.IsNullOrWhiteSpace(subject)) return null;
        return new(subject, ReadString(root, "email"), ReadBoolean(root, "email_verified"),
            ReadString(root, "given_name"), ReadString(root, "family_name"), ReadString(root, "name"),
            ReadString(root, "preferred_username"), ReadString(root, "phone_number"), ReadBoolean(root, "phone_number_verified"));
    }

    public string BuildLogoutUrl(OidcClientOptions client)
    {
        ValidateClient(client);
        if (client.LogoutRedirectParameter is not ("logout_uri" or "returnTo" or "post_logout_redirect_uri"))
            throw new ArgumentException("Unknown logout protocol.");
        return Query(client.LogoutEndpoint, new() { ["client_id"] = client.ClientId, [client.LogoutRedirectParameter] = client.LogoutCallbackUrl });
    }

    private static void ValidateClient(OidcClientOptions client)
    {
        foreach (var uri in new[] { client.Issuer, client.Authority, client.AuthorizationEndpoint, client.TokenEndpoint, client.UserInfoEndpoint, client.LogoutEndpoint })
            RequireHttps(uri);
        foreach (var callback in new[] { client.CallbackUrl, client.LogoutCallbackUrl })
            if (!Uri.TryCreate(callback, UriKind.Absolute, out var uri) || (uri.Scheme != "https" && !(uri.Scheme == "http" && uri.IsLoopback)) || uri.Fragment.Length > 0)
                throw new ArgumentException("Invalid callback configuration.");
        if (string.IsNullOrWhiteSpace(client.ClientId) || !client.Scopes.Contains("openid", StringComparer.Ordinal))
            throw new ArgumentException("Invalid OIDC client configuration.");
    }

    private static string Fingerprint(OidcClientOptions client) => Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(
        string.Join('\n', client.Issuer, client.Authority, client.ClientId, client.ClientSecret, client.CallbackUrl,
            client.AuthorizationEndpoint, client.TokenEndpoint, client.UserInfoEndpoint, string.Join(',', client.AllowedAlgorithms)))));
    private static void RequireHttps(string value)
    {
        if (!Uri.TryCreate(value, UriKind.Absolute, out var uri) || uri.Scheme != "https" || uri.UserInfo.Length > 0 || uri.Fragment.Length > 0)
            throw new ArgumentException("A trusted HTTPS endpoint is required.");
    }
    private static string Query(string endpoint, Dictionary<string, string> fields) => endpoint + (endpoint.Contains('?') ? "&" : "?") +
        string.Join('&', fields.Select(field => Uri.EscapeDataString(field.Key) + "=" + Uri.EscapeDataString(field.Value)));
    private static ProviderTokenResponse Failure(string reason) => new() { Success = false, ErrorMessage = reason };
    private static string RandomValue() => Encode(RandomNumberGenerator.GetBytes(32));
    private static string Encode(byte[] value) => Convert.ToBase64String(value).TrimEnd('=').Replace('+', '-').Replace('/', '_');
    private static string? ReadString(JsonElement root, string key) => root.TryGetProperty(key, out var value) && value.ValueKind == JsonValueKind.String ? value.GetString() : null;
    private static bool ReadBoolean(JsonElement root, string key) => root.TryGetProperty(key, out var value) &&
        (value.ValueKind == JsonValueKind.True || value.ValueKind == JsonValueKind.String && bool.TryParse(value.GetString(), out var parsed) && parsed);
    private static async Task<JsonDocument> ReadDocument(HttpResponseMessage response, CancellationToken cancellationToken)
    {
        await using var stream = await response.Content.ReadAsStreamAsync(cancellationToken);
        return await JsonDocument.ParseAsync(stream, cancellationToken: cancellationToken);
    }
}
