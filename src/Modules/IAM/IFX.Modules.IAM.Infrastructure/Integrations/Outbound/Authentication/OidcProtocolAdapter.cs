using IFX.Modules.IAM.Application.Identity.Interfaces;
using IFX.Modules.IAM.Application.Identity.Ports;
using IFX.Platform.Authentication.Contracts.V1;
using Microsoft.Extensions.Configuration;
using LocalUserInfo = IFX.Modules.IAM.Application.Identity.Interfaces.OidcUserInfo;
using ProvisioningUserInfo = IFX.Modules.IAM.Application.Identity.Ports.OidcUserInfo;

namespace IFX.Modules.IAM.Infrastructure.Integrations.Outbound.Authentication;

internal sealed class OidcProtocolAdapter(IOidcProtocolContract protocol) : IOidcProtocolService, IOidcDiscoveryService, IOidcUserInfoClient
{
    public OidcAuthorizationUrl Begin(OidcClientConfiguration client, string browserBinding)
    {
        var result = protocol.Begin(Map(client), browserBinding);
        return new() { Url = result.Url, State = result.State };
    }

    public async Task<AuthTokenResult> RedeemAsync(OidcClientConfiguration client, string code, string state, string browserBinding)
    {
        var result = await protocol.RedeemAsync(Map(client), code, state, browserBinding);
        return new() { Success = result.Success, Issuer = result.Issuer, Subject = result.Subject,
            AccessToken = result.AccessToken, IdToken = result.IdToken, RefreshToken = result.RefreshToken,
            ExpiresIn = result.ExpiresIn, TokenType = result.TokenType, ErrorMessage = result.ErrorMessage };
    }

    public async Task<LocalUserInfo?> GetUserInfoAsync(string endpoint, string accessToken)
    {
        var info = await protocol.GetUserInfoAsync(endpoint, accessToken);
        return info is null ? null : new() { Subject = info.Subject, Email = info.Email, EmailVerified = info.EmailVerified,
            GivenName = info.GivenName, FamilyName = info.FamilyName, Name = info.Name,
            PreferredUsername = info.PreferredUsername, PhoneNumber = info.PhoneNumber, PhoneNumberVerified = info.PhoneNumberVerified };
    }

    public string BuildLogoutUrl(OidcClientConfiguration client) => protocol.BuildLogoutUrl(Map(client));
    public async Task<OidcDiscoveryDocument> GetDiscoveryDocumentAsync(string issuer, CancellationToken cancellationToken = default)
    {
        var document = await protocol.DiscoverAsync(issuer, cancellationToken);
        return new() { Issuer = document.Issuer, UserInfoEndpoint = document.UserInfoEndpoint };
    }
    public async Task<ProvisioningUserInfo?> GetAsync(string endpoint, string accessToken, CancellationToken cancellationToken = default)
    {
        var info = await protocol.GetUserInfoAsync(endpoint, accessToken, cancellationToken);
        return info is null ? null : new(info.Email, info.GivenName, info.FamilyName, info.EmailVerified, info.Subject);
    }

    private static OidcClientOptions Map(OidcClientConfiguration client) => new()
    {
        Issuer = client.Issuer, Authority = client.Authority, ClientId = client.ClientId, ClientSecret = client.ClientSecret,
        AuthorizationEndpoint = client.AuthorizationEndpoint, TokenEndpoint = client.TokenEndpoint, UserInfoEndpoint = client.UserInfoEndpoint,
        LogoutEndpoint = client.LogoutEndpoint, CallbackUrl = client.CallbackUrl, LogoutCallbackUrl = client.LogoutCallbackUrl,
        Scopes = client.Scopes.ToArray(), AllowedAlgorithms = client.AllowedAlgorithms.ToArray(),
        StateLifetimeSeconds = client.StateLifetimeSeconds, LogoutRedirectParameter = client.LogoutRedirectParameter
    };
}

internal sealed class OidcClientConfigurationSource(IConfiguration configuration) : IOidcClientConfigurationSource
{
    public OidcClientConfiguration GetDefault()
    {
        var provider = configuration["Authentication:Provider"] ?? "Cognito";
        if (provider.Equals("Cognito", StringComparison.OrdinalIgnoreCase))
        {
            var section = configuration.GetSection("CognitoOidcSettings");
            var domain = "https://" + Required(section, "Domain").Replace("https://", "", StringComparison.Ordinal).TrimEnd('/');
            var issuer = configuration["CognitoSettings:Authority"];
            if (string.IsNullOrWhiteSpace(issuer))
                issuer = $"https://cognito-idp.{configuration["CognitoSettings:Region"] ?? "us-east-1"}.amazonaws.com/{configuration["CognitoSettings:UserPoolId"]}";
            return new()
            {
                Issuer = issuer, Authority = issuer, ClientId = Required(section, "ClientId"), ClientSecret = section["ClientSecret"],
                AuthorizationEndpoint = domain + "/login", TokenEndpoint = domain + "/oauth2/token",
                UserInfoEndpoint = domain + "/oauth2/userInfo", LogoutEndpoint = domain + "/logout",
                CallbackUrl = Required(section, "CallbackUrl"), LogoutCallbackUrl = Required(section, "LogoutCallbackUrl"),
                Scopes = section.GetSection("Scopes").Get<string[]>() ?? ["openid", "email", "profile"],
                StateLifetimeSeconds = section.GetValue("StateCacheDurationSeconds", 300), LogoutRedirectParameter = "logout_uri"
            };
        }
        if (provider.Equals("Auth0", StringComparison.OrdinalIgnoreCase))
        {
            var section = configuration.GetSection("Auth0");
            var issuer = "https://" + Required(section, "Domain").Replace("https://", "", StringComparison.Ordinal).TrimEnd('/') + "/";
            return new()
            {
                Issuer = issuer, Authority = issuer, ClientId = Required(section, "ClientId"), ClientSecret = section["ClientSecret"],
                AuthorizationEndpoint = issuer + "authorize", TokenEndpoint = issuer + "oauth/token",
                UserInfoEndpoint = issuer + "userinfo", LogoutEndpoint = issuer + "v2/logout",
                CallbackUrl = Required(section, "CallbackUrl"), LogoutCallbackUrl = Required(section, "LogoutCallbackUrl"),
                LogoutRedirectParameter = "returnTo"
            };
        }
        throw new InvalidOperationException("Unknown identity provider configuration.");
    }
    private static string Required(IConfiguration configuration, string key) => !string.IsNullOrWhiteSpace(configuration[key])
        ? configuration[key]! : throw new InvalidOperationException($"OIDC configuration is missing {key}.");
}
