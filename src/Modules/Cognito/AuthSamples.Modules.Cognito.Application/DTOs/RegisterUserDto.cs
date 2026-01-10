namespace AuthSamples.Modules.Cognito.Application.DTOs;

public record RegisterUserDto(
    string Email,
    string Password,
    string Username,
    string FirstName,
    string LastName,
    string PhoneNumber,
    string BirthDate);

public class RegisterUserResponse
{
    public Guid UserId { get; init; }
    public string Subject { get; init; } = string.Empty;
    public bool RequiresConfirmation { get; init; }
    public string Message { get; init; } = string.Empty;
    public string RoleName { get; init; } = "User";
}
