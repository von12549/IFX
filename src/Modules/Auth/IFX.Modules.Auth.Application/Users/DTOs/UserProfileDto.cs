namespace IFX.Modules.Auth.Application.DTOs;

public class UserProfileDto
{
    public Guid Id { get; init; }
    //public string Subject { get; init; } = string.Empty;
    public string Email { get; init; } = string.Empty;
    public string DisplayName { get; init; } = string.Empty;
    public string FirstName { get; init; } = string.Empty;
    public string LastName { get; init; } = string.Empty;
    public string BirthDate { get; set; } = string.Empty;
    public string PhoneNumber { get; init; } = string.Empty;
    public bool EmailVerified { get; init; }
    public bool IsActive { get; init; }
    public string Issuer { get; init; } = string.Empty;
    public UserRoleDto? Role { get; init; }
    public DateTime CreatedAt { get; init; }
}
