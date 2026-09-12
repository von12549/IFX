namespace IFX.Platform.Authentication.Contracts.V1;

public interface IExternalAccountContract
{
    Task<ProviderSignUpResponse> SignUpAsync(string email, string password, string username, string firstName, string lastName, string birthDate, string phoneNumber);
    Task<bool> ConfirmSignUpAsync(string username, string confirmationCode);
    Task<bool> ResendConfirmationCodeAsync(string username);
    Task<ProviderUserInfoDto> GetUserAsync(string accessToken);
}
public interface ICredentialAuthenticationContract
{
    Task<ProviderTokenResponse> AuthenticateAsync(string username, string password);
}
public interface ITokenLifecycleContract
{
    Task<bool> SignOutAsync(string accessToken);
    Task<ProviderTokenResponse> RefreshTokenAsync(string refreshToken, string username);
    Task<bool> RevokeTokenAsync(string refreshToken);
}
public class ProviderSignUpResponse
{
    public bool Success { get; set; }
    public string? Subject { get; set; }
    public bool UserConfirmed { get; set; }
    public string? ErrorMessage { get; set; }
}

public class ProviderTokenResponse
{
    public bool Success { get; set; }
    public string? AccessToken { get; set; }
    public string? IdToken { get; set; }
    public string? RefreshToken { get; set; }
    public int ExpiresIn { get; set; }
    public string TokenType { get; set; } = "Bearer";
    public string? ErrorMessage { get; set; }
    public string? Issuer { get; set; }
    public string? Subject { get; set; }
}

public class ProviderUserInfoDto
{
    public string Subject { get; set; } = string.Empty;
    public string Email { get; set; } = string.Empty;
    public string Username { get; set; } = string.Empty;
    public string FirstName { get; set; } = string.Empty;
    public string LastName { get; set; } = string.Empty;
    public string BirthDate { get; set; } = string.Empty;
    public string PhoneNumber { get; set; } = string.Empty;
    public bool EmailVerified { get; set; }
    public bool PhoneNumberVerified { get; set; }
}
