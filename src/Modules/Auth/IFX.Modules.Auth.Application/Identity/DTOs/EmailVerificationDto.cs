namespace IFX.Modules.Auth.Application.Identity.DTOs;

public record SendEmailVerificationResponse(
    string Message,
    DateTimeOffset ExpiresAt,
    Guid TokenId);

public record VerifyEmailResponse(
    bool Success,
    string Message);

public record ResendEmailVerificationResponse(
    string Message,
    DateTimeOffset ExpiresAt,
    Guid TokenId);

public record EmailVerificationTokenInfo(
    Guid TokenId,
    Guid UserIdentityId,
    string Email,
    string Token,
    string Code,
    DateTimeOffset ExpiresAt);
