namespace IFX.Modules.IAM.Application.Identity.Interfaces;

public interface IIdentityProvider
{
    Task<ProviderSignUpResult> SignUpAsync(string email, string password, string username, string firstName, string lastName, string birthDate, string phoneNumber);
    Task<bool> ConfirmSignUpAsync(string username, string confirmationCode);
    Task<AuthTokenResult> AuthenticateAsync(string username, string password);
    Task<bool> SignOutAsync(string accessToken);
    Task<ProviderUserInfo> GetUserAsync(string accessToken);
    Task<AuthTokenResult> RefreshTokenAsync(string refreshToken, string username);
    Task<bool> ResendConfirmationCodeAsync(string username);
    Task<bool> RevokeTokenAsync(string refreshToken);
}

public class ProviderSignUpResult
{
    public bool Success { get; set; }
    public string? Subject { get; set; }
    public bool UserConfirmed { get; set; }
    public string? ErrorMessage { get; set; }
}

public class AuthTokenResult
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

public class ProviderUserInfo
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
