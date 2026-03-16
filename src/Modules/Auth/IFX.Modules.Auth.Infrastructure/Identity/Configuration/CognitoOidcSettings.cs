namespace IFX.Modules.Auth.Infrastructure.Identity.Configuration;

public class CognitoOidcSettings
{
    public const string SectionName = "CognitoOidcSettings";

    /// <summary>
    /// Cognito domain (e.g., myapp.auth.ap-southeast-2.amazoncognito.com)
    /// Do not include https:// prefix
    /// </summary>
    public string Domain { get; set; } = string.Empty;

    /// <summary>
    /// Gets the normalized domain (strips https:// if accidentally included)
    /// </summary>
    private string NormalizedDomain => Domain
        .Replace("https://", "")
        .Replace("http://", "")
        .TrimEnd('/');

    /// <summary>
    /// OAuth Client ID
    /// </summary>
    public string ClientId { get; set; } = string.Empty;

    /// <summary>
    /// OAuth Client Secret (for confidential clients)
    /// </summary>
    public string ClientSecret { get; set; } = string.Empty;

    /// <summary>
    /// Callback URL for OAuth authorization code flow
    /// </summary>
    public string CallbackUrl { get; set; } = string.Empty;

    /// <summary>
    /// Logout callback URL
    /// </summary>
    public string LogoutCallbackUrl { get; set; } = string.Empty;

    /// <summary>
    /// Frontend callback URL for SPA flows (optional).
    /// If set, the OAuth callback will redirect to this URL with tokens in URL fragment.
    /// </summary>
    public string? FrontendCallbackUrl { get; set; }

    /// <summary>
    /// OAuth scopes to request
    /// </summary>
    public string[] Scopes { get; set; } = ["openid", "email", "profile"];

    /// <summary>
    /// PKCE state/verifier cache duration in seconds
    /// </summary>
    public int StateCacheDurationSeconds { get; set; } = 300;

    /// <summary>
    /// Gets the authorization endpoint URL (Cognito Hosted UI login page)
    /// </summary>
    public string AuthorizationEndpoint => $"https://{NormalizedDomain}/login";

    /// <summary>
    /// Gets the token endpoint URL
    /// </summary>
    public string TokenEndpoint => $"https://{NormalizedDomain}/oauth2/token";

    /// <summary>
    /// Gets the userinfo endpoint URL
    /// </summary>
    public string UserInfoEndpoint => $"https://{NormalizedDomain}/oauth2/userInfo";

    /// <summary>
    /// Gets the logout endpoint URL
    /// </summary>
    public string LogoutEndpoint => $"https://{NormalizedDomain}/logout";
}
