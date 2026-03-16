using System.Text.Json;
using System.Text.Json.Serialization;
using IFX.Modules.Auth.Application.Identity.Interfaces;
using Microsoft.Extensions.Caching.Memory;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.Auth.Infrastructure.Identity.Services;

/// <summary>
/// Service for discovering OpenID Connect configuration from identity providers
/// </summary>
public class OidcDiscoveryService : IOidcDiscoveryService
{
    private readonly IHttpClientFactory _httpClientFactory;
    private readonly IMemoryCache _cache;
    private readonly ILogger<OidcDiscoveryService> _logger;

    private const string HttpClientName = "OidcDiscovery";
    private const string CacheKeyPrefix = "oidc_discovery_";
    private static readonly TimeSpan CacheDuration = TimeSpan.FromHours(1);

    private static readonly JsonSerializerOptions JsonOptions = new()
    {
        PropertyNameCaseInsensitive = true
    };

    public OidcDiscoveryService(
        IHttpClientFactory httpClientFactory,
        IMemoryCache cache,
        ILogger<OidcDiscoveryService> logger)
    {
        _httpClientFactory = httpClientFactory;
        _cache = cache;
        _logger = logger;
    }

    public async Task<OidcDiscoveryDocument> GetDiscoveryDocumentAsync(
        string issuer,
        CancellationToken cancellationToken = default)
    {
        if (string.IsNullOrWhiteSpace(issuer))
        {
            throw new ArgumentException("Issuer cannot be null or empty", nameof(issuer));
        }

        // Normalize issuer URL
        var normalizedIssuer = NormalizeIssuer(issuer);
        var cacheKey = $"{CacheKeyPrefix}{normalizedIssuer}";

        // Check cache first
        if (_cache.TryGetValue<OidcDiscoveryDocument>(cacheKey, out var cachedDocument) && cachedDocument != null)
        {
            _logger.LogDebug("Returning cached OIDC discovery document for {Issuer}", normalizedIssuer);
            return cachedDocument;
        }

        // Fetch from well-known endpoint
        var discoveryUrl = $"{normalizedIssuer}/.well-known/openid-configuration";
        _logger.LogInformation("Fetching OIDC discovery document from {Url}", discoveryUrl);

        try
        {
            var httpClient = _httpClientFactory.CreateClient(HttpClientName);
            var response = await httpClient.GetAsync(discoveryUrl, cancellationToken);

            if (!response.IsSuccessStatusCode)
            {
                var errorContent = await response.Content.ReadAsStringAsync(cancellationToken);
                _logger.LogWarning(
                    "Failed to fetch OIDC discovery document from {Url}: {StatusCode} - {Error}",
                    discoveryUrl, response.StatusCode, errorContent);
                throw new InvalidOperationException(
                    $"Failed to fetch OIDC discovery document: {response.StatusCode}");
            }

            var content = await response.Content.ReadAsStringAsync(cancellationToken);
            var rawDocument = JsonSerializer.Deserialize<OidcDiscoveryDocumentRaw>(content, JsonOptions);

            if (rawDocument == null)
            {
                throw new InvalidOperationException("Invalid OIDC discovery document response");
            }

            var document = MapToDiscoveryDocument(rawDocument);

            // Cache the result
            _cache.Set(cacheKey, document, CacheDuration);
            _logger.LogInformation(
                "Successfully fetched and cached OIDC discovery document for {Issuer}", normalizedIssuer);

            return document;
        }
        catch (HttpRequestException ex)
        {
            _logger.LogError(ex, "Network error fetching OIDC discovery document from {Url}", discoveryUrl);
            throw new InvalidOperationException(
                $"Network error fetching OIDC discovery document from {discoveryUrl}", ex);
        }
        catch (JsonException ex)
        {
            _logger.LogError(ex, "Failed to parse OIDC discovery document from {Url}", discoveryUrl);
            throw new InvalidOperationException(
                $"Failed to parse OIDC discovery document from {discoveryUrl}", ex);
        }
    }

    private static string NormalizeIssuer(string issuer)
    {
        var normalized = issuer.Trim();

        // Ensure https:// prefix
        if (!normalized.StartsWith("https://", StringComparison.OrdinalIgnoreCase) &&
            !normalized.StartsWith("http://", StringComparison.OrdinalIgnoreCase))
        {
            normalized = $"https://{normalized}";
        }

        // Remove trailing slash
        return normalized.TrimEnd('/');
    }

    private static OidcDiscoveryDocument MapToDiscoveryDocument(OidcDiscoveryDocumentRaw raw)
    {
        return new OidcDiscoveryDocument
        {
            Issuer = raw.Issuer ?? string.Empty,
            AuthorizationEndpoint = raw.AuthorizationEndpoint ?? string.Empty,
            TokenEndpoint = raw.TokenEndpoint ?? string.Empty,
            UserInfoEndpoint = raw.UserinfoEndpoint,
            JwksUri = raw.JwksUri ?? string.Empty,
            EndSessionEndpoint = raw.EndSessionEndpoint,
            RevocationEndpoint = raw.RevocationEndpoint,
            IntrospectionEndpoint = raw.IntrospectionEndpoint,
            ScopesSupported = raw.ScopesSupported ?? [],
            ResponseTypesSupported = raw.ResponseTypesSupported ?? [],
            GrantTypesSupported = raw.GrantTypesSupported ?? [],
            SubjectTypesSupported = raw.SubjectTypesSupported ?? [],
            IdTokenSigningAlgValuesSupported = raw.IdTokenSigningAlgValuesSupported ?? [],
            TokenEndpointAuthMethodsSupported = raw.TokenEndpointAuthMethodsSupported ?? [],
            ClaimsSupported = raw.ClaimsSupported ?? [],
            CodeChallengeMethodsSupported = raw.CodeChallengeMethodsSupported ?? []
        };
    }

    /// <summary>
    /// Raw JSON model matching the OIDC discovery document format
    /// </summary>
    private class OidcDiscoveryDocumentRaw
    {
        [JsonPropertyName("issuer")]
        public string? Issuer { get; set; }

        [JsonPropertyName("authorization_endpoint")]
        public string? AuthorizationEndpoint { get; set; }

        [JsonPropertyName("token_endpoint")]
        public string? TokenEndpoint { get; set; }

        [JsonPropertyName("userinfo_endpoint")]
        public string? UserinfoEndpoint { get; set; }

        [JsonPropertyName("jwks_uri")]
        public string? JwksUri { get; set; }

        [JsonPropertyName("end_session_endpoint")]
        public string? EndSessionEndpoint { get; set; }

        [JsonPropertyName("revocation_endpoint")]
        public string? RevocationEndpoint { get; set; }

        [JsonPropertyName("introspection_endpoint")]
        public string? IntrospectionEndpoint { get; set; }

        [JsonPropertyName("scopes_supported")]
        public string[]? ScopesSupported { get; set; }

        [JsonPropertyName("response_types_supported")]
        public string[]? ResponseTypesSupported { get; set; }

        [JsonPropertyName("grant_types_supported")]
        public string[]? GrantTypesSupported { get; set; }

        [JsonPropertyName("subject_types_supported")]
        public string[]? SubjectTypesSupported { get; set; }

        [JsonPropertyName("id_token_signing_alg_values_supported")]
        public string[]? IdTokenSigningAlgValuesSupported { get; set; }

        [JsonPropertyName("token_endpoint_auth_methods_supported")]
        public string[]? TokenEndpointAuthMethodsSupported { get; set; }

        [JsonPropertyName("claims_supported")]
        public string[]? ClaimsSupported { get; set; }

        [JsonPropertyName("code_challenge_methods_supported")]
        public string[]? CodeChallengeMethodsSupported { get; set; }
    }
}
