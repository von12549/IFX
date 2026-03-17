using IFX.Modules.Auth.Application.Identity.Interfaces;

namespace IFX.Modules.Auth.Infrastructure.IdentityProviders.Auth0;

public class Auth0OidcService : IOidcAuthService
{
    public OidcAuthorizationUrl BuildAuthorizationUrl(string? redirectUri = null)
        => throw new NotImplementedException("Auth0 OIDC service is not yet implemented.");

    public Task<OidcTokenResult> ExchangeCodeForTokensAsync(string code, string state, string? redirectUri = null)
        => throw new NotImplementedException("Auth0 OIDC service is not yet implemented.");

    public Task<OidcUserInfo> GetUserInfoAsync(string accessToken)
        => throw new NotImplementedException("Auth0 OIDC service is not yet implemented.");

    public string BuildLogoutUrl(string? idTokenHint = null, string? postLogoutRedirectUri = null)
        => throw new NotImplementedException("Auth0 OIDC service is not yet implemented.");

    public bool ValidateState(string state)
        => throw new NotImplementedException("Auth0 OIDC service is not yet implemented.");
}
