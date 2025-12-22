namespace AuthSamples.Modules.Cognito.Application.DTOs;

public record ConfirmRegistrationDto(
    string Email,
    string ConfirmationCode);

public class ConfirmRegistrationResponse
{
    public bool Success { get; init; }
    public string Message { get; init; } = string.Empty;
}
