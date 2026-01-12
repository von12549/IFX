namespace AuthSamples.Modules.Auth.Application.DTOs;

public class RefreshTokenResponse
{
    public string AccessToken { get; init; } = string.Empty;
    public string IdToken { get; init; } = string.Empty;
    public string RefreshToken { get; init; } = string.Empty;
    public int ExpiresIn { get; init; }
    public string TokenType { get; init; } = string.Empty;
    public DateTime ExpiresAt { get; init; }
    public UserProfileDto? UserProfile { get; init; }
}
