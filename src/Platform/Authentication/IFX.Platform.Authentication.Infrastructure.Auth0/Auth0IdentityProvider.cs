using IFX.Platform.Authentication.Contracts.V1;

namespace IFX.Platform.Authentication.Infrastructure.Auth0;

public class Auth0IdentityProvider : IExternalAccountContract, ICredentialAuthenticationContract, ITokenLifecycleContract
{
    public Task<ProviderSignUpResponse> SignUpAsync(string email, string password, string username, string firstName, string lastName, string birthDate, string phoneNumber)
        => throw new NotImplementedException("Auth0 provider is not yet implemented.");

    public Task<bool> ConfirmSignUpAsync(string username, string confirmationCode)
        => throw new NotImplementedException("Auth0 provider is not yet implemented.");

    public Task<ProviderTokenResponse> AuthenticateAsync(string username, string password)
        => throw new NotImplementedException("Auth0 provider is not yet implemented.");

    public Task<bool> SignOutAsync(string accessToken)
        => throw new NotImplementedException("Auth0 provider is not yet implemented.");

    public Task<ProviderUserInfoDto> GetUserAsync(string accessToken)
        => throw new NotImplementedException("Auth0 provider is not yet implemented.");

    public Task<ProviderTokenResponse> RefreshTokenAsync(string refreshToken, string username)
        => throw new NotImplementedException("Auth0 provider is not yet implemented.");

    public Task<bool> ResendConfirmationCodeAsync(string username)
        => throw new NotImplementedException("Auth0 provider is not yet implemented.");

    public Task<bool> RevokeTokenAsync(string refreshToken)
        => throw new NotImplementedException("Auth0 provider is not yet implemented.");
}
