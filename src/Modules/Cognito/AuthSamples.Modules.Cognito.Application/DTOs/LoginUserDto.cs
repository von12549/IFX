namespace AuthSamples.Modules.Cognito.Application.DTOs;

public record LoginUserDto(
    string Email,
    string Password);

public class LoginUserResponse
{
    public string AccessToken { get; init; } = string.Empty;
    public string RefreshToken { get; init; } = string.Empty;
    public string IdToken { get; init; } = string.Empty;
    public int ExpiresIn { get; init; }
    public UserProfileDto UserProfile { get; init; } = null!;
}
