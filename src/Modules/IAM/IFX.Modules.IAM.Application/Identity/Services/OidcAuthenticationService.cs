using System.Text.Json;
using IFX.Modules.IAM.Application.Identity.Interfaces;
using IFX.Modules.IAM.Application.Identity.Queries.GetOrProvisionUser;
using IFX.Modules.IAM.Application.Interfaces;
using IFX.Modules.IAM.Domain.Identity;
using MediatR;

namespace IFX.Modules.IAM.Application.Identity.Services;

public sealed class OidcAuthenticationService(IOidcClientConfigurationSource configuration,
    IOidcProtocolService protocol, IUnitOfWork unitOfWork, ISender sender) : IOidcAuthService
{
    public async Task<OidcAuthorizationUrl> BuildAuthorizationUrl(string browserBinding, string? redirectUri = null)
    {
        var (client, _) = await TrustedClient();
        RequireExactCallback(redirectUri, client.CallbackUrl);
        return protocol.Begin(client, browserBinding);
    }

    public async Task<OidcTokenResult> ExchangeCodeForTokensAsync(string code, string state, string browserBinding, string? redirectUri = null)
    {
        var (client, idp) = await TrustedClient();
        RequireExactCallback(redirectUri, client.CallbackUrl);
        var tokens = await protocol.RedeemAsync(client, code, state, browserBinding);
        if (!tokens.Success || tokens.Issuer != idp.Issuer || string.IsNullOrWhiteSpace(tokens.Subject))
            return new() { Error = tokens.ErrorMessage ?? "protocol_rejected", ErrorDescription = "External identity validation failed" };
        var admission = await sender.Send(new GetOrProvisionUserQuery(
            tokens.Issuer, tokens.Subject, tokens.AccessToken ?? string.Empty, idp.AutoProvisionEnabled, idp.Id, idp.IdpType, null));
        if (!admission.IsSuccess)
            return new() { Error = "local_admission_rejected", ErrorDescription = "Local account admission failed" };
        return new() { Success = true, AccessToken = tokens.AccessToken, IdToken = tokens.IdToken,
            RefreshToken = tokens.RefreshToken, ExpiresIn = tokens.ExpiresIn, TokenType = tokens.TokenType };
    }

    public async Task<OidcUserInfo> GetUserInfoAsync(string accessToken)
    {
        var (client, _) = await TrustedClient();
        return await protocol.GetUserInfoAsync(client.UserInfoEndpoint, accessToken)
            ?? throw new InvalidOperationException("Userinfo unavailable.");
    }

    public async Task<string> BuildLogoutUrl(string? idTokenHint = null, string? postLogoutRedirectUri = null)
    {
        var (client, _) = await TrustedClient();
        RequireExactCallback(postLogoutRedirectUri, client.LogoutCallbackUrl);
        return protocol.BuildLogoutUrl(client);
    }

    private async Task<(OidcClientConfiguration Client, Idp Idp)> TrustedClient()
    {
        var client = configuration.GetDefault();
        var idp = await unitOfWork.Idps.GetEnabledByIssuerAsync(client.Issuer)
            ?? throw new InvalidOperationException("Configured identity provider is disabled or unknown.");
        client.Authority = idp.Authority;
        var algorithms = JsonSerializer.Deserialize<string[]>(idp.AllowedAlgs) ?? [];
        if (algorithms.Length > 0) client.AllowedAlgorithms = algorithms;
        if (client.AllowedAlgorithms.Length == 0) throw new InvalidOperationException("Identity provider algorithms are not configured.");
        return (client, idp);
    }

    private static void RequireExactCallback(string? supplied, string configured)
    {
        if (supplied is not null && !string.Equals(supplied, configured, StringComparison.Ordinal))
            throw new ArgumentException("Callback URI does not match the configured client.");
    }
}
