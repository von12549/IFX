namespace AuthSamples.Modules.Auth.Presentation.Models.Requests.EmailVerification;

public record VerifyEmailRequest(
    Guid UserIdentityId,
    string? Token,
    string? Code);
