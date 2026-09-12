namespace IFX.Modules.IAM.Presentation.Users.Requests;

public record VerifyEmailRequest(
    Guid UserIdentityId,
    string? Token,
    string? Code);
