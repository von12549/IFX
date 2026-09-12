namespace IFX.Modules.IAM.Application.Identity.Interfaces;

public sealed class OidcClientConfiguration
{
    public required string Issuer { get; set; }
    public required string Authority { get; set; }
    public required string ClientId { get; set; }
    public string? ClientSecret { get; set; }
    public required string AuthorizationEndpoint { get; set; }
    public required string TokenEndpoint { get; set; }
    public required string UserInfoEndpoint { get; set; }
    public required string LogoutEndpoint { get; set; }
    public required string CallbackUrl { get; set; }
    public required string LogoutCallbackUrl { get; set; }
    public string[] Scopes { get; set; } = ["openid", "email", "profile"];
    public string[] AllowedAlgorithms { get; set; } = ["RS256"];
    public int StateLifetimeSeconds { get; set; } = 300;
    public string LogoutRedirectParameter { get; set; } = "post_logout_redirect_uri";
}

public interface IOidcClientConfigurationSource
{
    OidcClientConfiguration GetDefault();
}
public interface IOidcProtocolService
{
    OidcAuthorizationUrl Begin(OidcClientConfiguration client, string browserBinding);
    Task<AuthTokenResult> RedeemAsync(OidcClientConfiguration client, string code, string state, string browserBinding);
    Task<OidcUserInfo?> GetUserInfoAsync(string endpoint, string accessToken);
    string BuildLogoutUrl(OidcClientConfiguration client);
}