namespace IFX.Platform.Authentication.Contracts.V1;

public sealed class OidcClientOptions
{
    public required string Issuer { get; init; }
    public required string Authority { get; init; }
    public required string ClientId { get; init; }
    public string? ClientSecret { get; init; }
    public required string AuthorizationEndpoint { get; init; }
    public required string TokenEndpoint { get; init; }
    public required string UserInfoEndpoint { get; init; }
    public required string LogoutEndpoint { get; init; }
    public required string CallbackUrl { get; init; }
    public required string LogoutCallbackUrl { get; init; }
    public string[] Scopes { get; init; } = ["openid", "email", "profile"];
    public string[] AllowedAlgorithms { get; init; } = ["RS256"];
    public int StateLifetimeSeconds { get; init; } = 300;
    public string LogoutRedirectParameter { get; init; } = "post_logout_redirect_uri";
}

public sealed record OidcAuthorizationResponse(string Url, string State);
public sealed record OidcMetadataDto(string Issuer, string? UserInfoEndpoint);
public sealed record OidcUserInfoDto(string Subject, string? Email, bool EmailVerified,
    string? GivenName, string? FamilyName, string? Name = null, string? PreferredUsername = null,
    string? PhoneNumber = null, bool PhoneNumberVerified = false);

public interface IOidcProtocolContract
{
    OidcAuthorizationResponse Begin(OidcClientOptions client, string browserBinding);
    Task<ProviderTokenResponse> RedeemAsync(OidcClientOptions client, string code, string state,
        string browserBinding, CancellationToken cancellationToken = default);
    Task<OidcMetadataDto> DiscoverAsync(string trustedIssuer, CancellationToken cancellationToken = default);
    Task<OidcUserInfoDto?> GetUserInfoAsync(string trustedEndpoint, string accessToken, CancellationToken cancellationToken = default);
    string BuildLogoutUrl(OidcClientOptions client);
}
