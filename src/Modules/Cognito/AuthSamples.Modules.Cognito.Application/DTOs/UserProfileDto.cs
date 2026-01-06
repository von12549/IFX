namespace AuthSamples.Modules.Cognito.Application.DTOs;

public class UserProfileDto
{
    public Guid Id { get; init; }
    public string CognitoUserId { get; init; } = string.Empty;
    public string Email { get; init; } = string.Empty;
    public string Username { get; init; } = string.Empty;
    public string FirstName { get; init; } = string.Empty;
    public string LastName { get; init; } = string.Empty;
    public string BirthDate { get; set; } = string.Empty;
    public string PhoneNumber { get; init; } = string.Empty;
    public bool EmailVerified { get; init; }
    public bool IsActive { get; init; }
    public UserRoleDto? Role { get; init; }
    public DateTime CreatedAt { get; init; }
}
