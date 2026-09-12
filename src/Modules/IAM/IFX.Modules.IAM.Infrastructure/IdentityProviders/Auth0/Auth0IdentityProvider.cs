using IFX.Modules.IAM.Application.Identity.Interfaces;

namespace IFX.Modules.IAM.Infrastructure.IdentityProviders.Auth0;

public class Auth0IdentityProvider : IIdentityProvider
{
    public Task<ProviderSignUpResult> SignUpAsync(string email, string password, string username, string firstName, string lastName, string birthDate, string phoneNumber)
        => throw new NotImplementedException("Auth0 provider is not yet implemented.");

    public Task<bool> ConfirmSignUpAsync(string username, string confirmationCode)
        => throw new NotImplementedException("Auth0 provider is not yet implemented.");

    public Task<AuthTokenResult> AuthenticateAsync(string username, string password)
        => throw new NotImplementedException("Auth0 provider is not yet implemented.");

    public Task<bool> SignOutAsync(string accessToken)
        => throw new NotImplementedException("Auth0 provider is not yet implemented.");

    public Task<ProviderUserInfo> GetUserAsync(string accessToken)
        => throw new NotImplementedException("Auth0 provider is not yet implemented.");

    public Task<AuthTokenResult> RefreshTokenAsync(string refreshToken, string username)
        => throw new NotImplementedException("Auth0 provider is not yet implemented.");

    public Task<bool> ResendConfirmationCodeAsync(string username)
        => throw new NotImplementedException("Auth0 provider is not yet implemented.");

    public Task<bool> RevokeTokenAsync(string refreshToken)
        => throw new NotImplementedException("Auth0 provider is not yet implemented.");
}
