using IFX.Modules.IAM.Application.Users.DTOs;
namespace IFX.Modules.IAM.Application.Identity.DTOs;

public class RefreshTokenResponse
{
    public string AccessToken { get; init; } = string.Empty;
    public string IdToken { get; init; } = string.Empty;
    public string RefreshToken { get; init; } = string.Empty;
    public int ExpiresIn { get; init; }
    public string TokenType { get; init; } = string.Empty;
    public DateTimeOffset ExpiresAt { get; init; }
    public UserProfileDto? UserProfile { get; init; }
}
