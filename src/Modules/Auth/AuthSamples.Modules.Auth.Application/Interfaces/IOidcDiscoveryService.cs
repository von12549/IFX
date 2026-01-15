namespace AuthSamples.Modules.Auth.Application.Interfaces;

/// <summary>
/// Service for discovering OpenID Connect configuration from identity providers
/// </summary>
public interface IOidcDiscoveryService
{
    /// <summary>
    /// Fetches OpenID Connect configuration from the well-known endpoint
    /// </summary>
    /// <param name="issuer">The issuer URL (e.g., https://cognito-idp.ap-southeast-2.amazonaws.com/ap-southeast-2_xxxxx)</param>
    /// <param name="cancellationToken">Cancellation token</param>
    /// <returns>OpenID Connect configuration</returns>
    Task<OidcDiscoveryDocument> GetDiscoveryDocumentAsync(string issuer, CancellationToken cancellationToken = default);
}

/// <summary>
/// OpenID Connect Discovery Document (RFC 8414)
/// </summary>
public class OidcDiscoveryDocument
{
    /// <summary>
    /// Issuer identifier
    /// </summary>
    public string Issuer { get; set; } = string.Empty;

    /// <summary>
    /// URL of the authorization endpoint
    /// </summary>
    public string AuthorizationEndpoint { get; set; } = string.Empty;

    /// <summary>
    /// URL of the token endpoint
    /// </summary>
    public string TokenEndpoint { get; set; } = string.Empty;

    /// <summary>
    /// URL of the userinfo endpoint
    /// </summary>
    public string? UserInfoEndpoint { get; set; }

    /// <summary>
    /// URL of the JWKS endpoint
    /// </summary>
    public string JwksUri { get; set; } = string.Empty;

    /// <summary>
    /// URL of the end session (logout) endpoint
    /// </summary>
    public string? EndSessionEndpoint { get; set; }

    /// <summary>
    /// URL of the revocation endpoint
    /// </summary>
    public string? RevocationEndpoint { get; set; }

    /// <summary>
    /// URL of the introspection endpoint
    /// </summary>
    public string? IntrospectionEndpoint { get; set; }

    /// <summary>
    /// Supported scopes
    /// </summary>
    public string[] ScopesSupported { get; set; } = [];

    /// <summary>
    /// Supported response types
    /// </summary>
    public string[] ResponseTypesSupported { get; set; } = [];

    /// <summary>
    /// Supported grant types
    /// </summary>
    public string[] GrantTypesSupported { get; set; } = [];

    /// <summary>
    /// Supported subject types
    /// </summary>
    public string[] SubjectTypesSupported { get; set; } = [];

    /// <summary>
    /// Supported ID token signing algorithms
    /// </summary>
    public string[] IdTokenSigningAlgValuesSupported { get; set; } = [];

    /// <summary>
    /// Supported token endpoint authentication methods
    /// </summary>
    public string[] TokenEndpointAuthMethodsSupported { get; set; } = [];

    /// <summary>
    /// Supported claims
    /// </summary>
    public string[] ClaimsSupported { get; set; } = [];

    /// <summary>
    /// Supported code challenge methods (PKCE)
    /// </summary>
    public string[] CodeChallengeMethodsSupported { get; set; } = [];
}
