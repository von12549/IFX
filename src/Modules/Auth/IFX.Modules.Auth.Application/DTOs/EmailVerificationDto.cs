namespace IFX.Modules.Auth.Application.DTOs;

public record SendEmailVerificationResponse(
    string Message,
    DateTime ExpiresAt,
    Guid TokenId);

public record VerifyEmailResponse(
    bool Success,
    string Message);

public record ResendEmailVerificationResponse(
    string Message,
    DateTime ExpiresAt,
    Guid TokenId);

public record EmailVerificationTokenInfo(
    Guid TokenId,
    Guid UserIdentityId,
    string Email,
    string Token,
    string Code,
    DateTime ExpiresAt);
