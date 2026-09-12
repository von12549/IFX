namespace IFX.Modules.IAM.Application.Identity.Ports;

public sealed record OidcUserInfo(
    string? Email,
    string? GivenName,
    string? FamilyName,
    bool EmailVerified);

public interface IOidcUserInfoClient
{
    Task<OidcUserInfo?> GetAsync(
        string endpoint,
        string accessToken,
        CancellationToken cancellationToken = default);
}
