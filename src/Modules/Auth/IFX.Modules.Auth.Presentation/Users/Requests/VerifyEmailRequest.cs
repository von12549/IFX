namespace IFX.Modules.Auth.Presentation.Users.Requests;

public record VerifyEmailRequest(
    Guid UserIdentityId,
    string? Token,
    string? Code);
