using IFX.Modules.IAM.Application.Identity.Interfaces;
using IFX.Platform.Authentication.Contracts.V1;

namespace IFX.Modules.IAM.Infrastructure.Integrations.Authentication;

internal sealed class ProviderServicesAdapter(IExternalAccountContract accounts,
    ICredentialAuthenticationContract credentials, ITokenLifecycleContract tokens)
    : IExternalAccountService, ICredentialAuthenticationService, ITokenLifecycleService
{
    public async Task<ProviderSignUpResult> SignUpAsync(string email, string password, string username, string firstName, string lastName, string birthDate, string phoneNumber)
        => Map(await accounts.SignUpAsync(email, password, username, firstName, lastName, birthDate, phoneNumber));
    public Task<bool> ConfirmSignUpAsync(string username, string confirmationCode) => accounts.ConfirmSignUpAsync(username, confirmationCode);
    public Task<bool> ResendConfirmationCodeAsync(string username) => accounts.ResendConfirmationCodeAsync(username);
    public async Task<ProviderUserInfo> GetUserAsync(string accessToken) => Map(await accounts.GetUserAsync(accessToken));
    public async Task<AuthTokenResult> AuthenticateAsync(string username, string password) => Map(await credentials.AuthenticateAsync(username, password));
    public Task<bool> SignOutAsync(string accessToken) => tokens.SignOutAsync(accessToken);
    public async Task<AuthTokenResult> RefreshTokenAsync(string refreshToken, string username) => Map(await tokens.RefreshTokenAsync(refreshToken, username));
    public Task<bool> RevokeTokenAsync(string refreshToken) => tokens.RevokeTokenAsync(refreshToken);
    private static ProviderSignUpResult Map(ProviderSignUpResponse value) => new()
    {
        Success = value.Success,
        Subject = value.Subject,
        UserConfirmed = value.UserConfirmed,
        ErrorMessage = value.ErrorMessage
    };
    private static AuthTokenResult Map(ProviderTokenResponse value) => new()
    {
        Success = value.Success,
        AccessToken = value.AccessToken,
        IdToken = value.IdToken,
        RefreshToken = value.RefreshToken,
        ExpiresIn = value.ExpiresIn,
        TokenType = value.TokenType,
        ErrorMessage = value.ErrorMessage,
        Issuer = value.Issuer,
        Subject = value.Subject
    };
    private static ProviderUserInfo Map(ProviderUserInfoDto value) => new()
    {
        Subject = value.Subject,
        Email = value.Email,
        Username = value.Username,
        FirstName = value.FirstName,
        LastName = value.LastName,
        BirthDate = value.BirthDate,
        PhoneNumber = value.PhoneNumber,
        EmailVerified = value.EmailVerified,
        PhoneNumberVerified = value.PhoneNumberVerified
    };

}