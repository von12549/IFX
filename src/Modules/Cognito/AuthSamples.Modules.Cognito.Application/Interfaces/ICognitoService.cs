namespace AuthSamples.Modules.Cognito.Application.Interfaces;

public interface ICognitoService
{
    Task<CognitoSignUpResult> SignUpAsync(string email, string password, string username, string firstName, string lastName,string birthDate, string phoneNumber);
    Task<bool> ConfirmSignUpAsync(string username, string confirmationCode);
    Task<CognitoAuthResult> AuthenticateAsync(string username, string password);
    Task<bool> SignOutAsync(string accessToken);
    Task<CognitoUserInfo> GetUserAsync(string accessToken);
    Task<bool> RefreshTokenAsync(string refreshToken);
    Task<bool> ResendConfirmationCodeAsync(string username);
}

public class CognitoSignUpResult
{
    public bool Success { get; set; }
    public string? CognitoUserId { get; set; }
    public bool UserConfirmed { get; set; }
    public string? ErrorMessage { get; set; }
}

public class CognitoAuthResult
{
    public bool Success { get; set; }
    public string? AccessToken { get; set; }
    public string? IdToken { get; set; }
    public string? RefreshToken { get; set; }
    public int ExpiresIn { get; set; }
    public string? ErrorMessage { get; set; }
}

public class CognitoUserInfo
{
    public string CognitoUserId { get; set; } = string.Empty;
    public string Email { get; set; } = string.Empty;
    public string Username { get; set; } = string.Empty;
    public string FirstName { get; set; } = string.Empty;
    public string LastName { get; set; } = string.Empty;
    public string BirthDate { get;set; } = string.Empty;
    public string PhoneNumber { get; set; } = string.Empty;
    public bool EmailVerified { get; set; }
    public bool PhoneNumberVerified { get; set; }
}
