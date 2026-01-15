namespace AuthSamples.Modules.Auth.Infrastructure.Configuration;

public class CognitoOidcSettings
{
    public const string SectionName = "CognitoOidcSettings";

    /// <summary>
    /// Cognito domain (e.g., myapp.auth.ap-southeast-2.amazoncognito.com)
    /// </summary>
    public string Domain { get; set; } = string.Empty;

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
    /// Gets the authorization endpoint URL
    /// </summary>
    public string AuthorizationEndpoint => $"https://{Domain}/oauth2/authorize";

    /// <summary>
    /// Gets the token endpoint URL
    /// </summary>
    public string TokenEndpoint => $"https://{Domain}/oauth2/token";

    /// <summary>
    /// Gets the userinfo endpoint URL
    /// </summary>
    public string UserInfoEndpoint => $"https://{Domain}/oauth2/userInfo";

    /// <summary>
    /// Gets the logout endpoint URL
    /// </summary>
    public string LogoutEndpoint => $"https://{Domain}/logout";
}
