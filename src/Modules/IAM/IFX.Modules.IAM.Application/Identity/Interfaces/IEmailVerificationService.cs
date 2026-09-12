using IFX.Modules.IAM.Application.Identity.DTOs;

namespace IFX.Modules.IAM.Application.Identity.Interfaces;

public interface IEmailVerificationService
{
    (string Token, string TokenHash, string Code) GenerateVerificationCredentials();
    string HashToken(string token);
    string GenerateVerificationCode();
    string BuildVerificationEmailHtml(string userName, string code, string verificationLink, int expiryMinutes);
    string BuildVerificationEmailPlainText(string userName, string code, string verificationLink, int expiryMinutes);
}
