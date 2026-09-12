namespace IFX.Modules.IAM.Application.Identity.Interfaces;

/// <summary>
/// Service for OIDC OAuth 2.0 authorization code flow operations
/// </summary>
public interface IOidcAuthService
{
    /// <summary>
    /// Builds the authorization URL for initiating OAuth flow
    /// </summary>
    /// <param name="redirectUri">Optional custom redirect URI</param>
    /// <returns>Authorization URL and state parameter for verification</returns>
    OidcAuthorizationUrl BuildAuthorizationUrl(string? redirectUri = null);

    /// <summary>
    /// Exchanges authorization code for tokens
    /// </summary>
    /// <param name="code">Authorization code from callback</param>
    /// <param name="state">State parameter for CSRF verification</param>
    /// <param name="redirectUri">Redirect URI used in authorization request</param>
    /// <returns>Token result with access, ID, and refresh tokens</returns>
    Task<OidcTokenResult> ExchangeCodeForTokensAsync(string code, string state, string? redirectUri = null);

    /// <summary>
    /// Gets user information using access token
    /// </summary>
    /// <param name="accessToken">Valid access token</param>
    /// <returns>User information from IdP</returns>
    Task<OidcUserInfo> GetUserInfoAsync(string accessToken);

    /// <summary>
    /// Builds the logout URL for ending the session
    /// </summary>
    /// <param name="idTokenHint">Optional ID token for logout hint</param>
    /// <param name="postLogoutRedirectUri">Optional redirect URI after logout</param>
    /// <returns>Logout URL</returns>
    string BuildLogoutUrl(string? idTokenHint = null, string? postLogoutRedirectUri = null);

    /// <summary>
    /// Validates the state parameter from callback
    /// </summary>
    /// <param name="state">State parameter to validate</param>
    /// <returns>True if state is valid and not expired</returns>
    bool ValidateState(string state);
}

/// <summary>
/// Result of building authorization URL
/// </summary>
public class OidcAuthorizationUrl
{
    /// <summary>
    /// Full authorization URL to redirect user to
    /// </summary>
    public string Url { get; set; } = string.Empty;

    /// <summary>
    /// State parameter for CSRF protection (store this for validation)
    /// </summary>
    public string State { get; set; } = string.Empty;

    /// <summary>
    /// PKCE code verifier (stored internally, needed for token exchange)
    /// </summary>
    public string CodeVerifier { get; set; } = string.Empty;
}

/// <summary>
/// Result of token exchange
/// </summary>
public class OidcTokenResult
{
    public bool Success { get; set; }
    public string? AccessToken { get; set; }
    public string? IdToken { get; set; }
    public string? RefreshToken { get; set; }
    public int ExpiresIn { get; set; }
    public string TokenType { get; set; } = "Bearer";
    public string? Error { get; set; }
    public string? ErrorDescription { get; set; }
}

/// <summary>
/// User information from OIDC userinfo endpoint
/// </summary>
public class OidcUserInfo
{
    public string Subject { get; set; } = string.Empty;
    public string? Email { get; set; }
    public bool EmailVerified { get; set; }
    public string? Name { get; set; }
    public string? GivenName { get; set; }
    public string? FamilyName { get; set; }
    public string? PreferredUsername { get; set; }
    public string? PhoneNumber { get; set; }
    public bool PhoneNumberVerified { get; set; }
}
