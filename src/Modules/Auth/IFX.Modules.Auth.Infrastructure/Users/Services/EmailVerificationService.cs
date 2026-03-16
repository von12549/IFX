using System.Security.Cryptography;
using System.Text;
using IFX.Modules.Auth.Application.Identity.Interfaces;

namespace IFX.Modules.Auth.Infrastructure.Users.Services;

public class EmailVerificationService : IEmailVerificationService
{
    private const int CodeLength = 6;

    public (string Token, string TokenHash, string Code) GenerateVerificationCredentials()
    {
        var token = Guid.NewGuid().ToString("N");
        var tokenHash = HashToken(token);
        var code = GenerateVerificationCode();

        return (token, tokenHash, code);
    }

    public string HashToken(string token)
    {
        var bytes = SHA256.HashData(Encoding.UTF8.GetBytes(token));
        return Convert.ToHexString(bytes).ToLowerInvariant();
    }

    public string GenerateVerificationCode()
    {
        var random = RandomNumberGenerator.GetInt32(0, 1000000);
        return random.ToString().PadLeft(CodeLength, '0');
    }

    public string BuildVerificationEmailHtml(string userName, string code, string verificationLink, int expiryMinutes)
    {
        return $"""
            <!DOCTYPE html>
            <html>
            <head>
                <meta charset="UTF-8">
                <title>Verify Your Email</title>
            </head>
            <body style="font-family: Arial, sans-serif; line-height: 1.6; color: #333; max-width: 600px; margin: 0 auto; padding: 20px;">
                <h1 style="color: #2c3e50;">Verify Your Email Address</h1>

                <p>Hello {EscapeHtml(userName)},</p>

                <p>Please verify your email address by clicking the button below or entering the verification code.</p>

                <div style="background-color: #f8f9fa; border-radius: 8px; padding: 20px; margin: 20px 0; text-align: center;">
                    <p style="margin: 0 0 10px 0; font-size: 14px; color: #666;">Your verification code:</p>
                    <p style="margin: 0; font-size: 32px; font-weight: bold; letter-spacing: 8px; color: #2c3e50;">{code}</p>
                </div>

                <div style="text-align: center; margin: 30px 0;">
                    <a href="{EscapeHtml(verificationLink)}"
                       style="display: inline-block; background-color: #3498db; color: white; padding: 12px 30px;
                              text-decoration: none; border-radius: 5px; font-weight: bold;">
                        Verify Email Address
                    </a>
                </div>

                <p style="color: #666; font-size: 14px;">
                    This verification link and code will expire in <strong>{expiryMinutes} minutes</strong>.
                </p>

                <p style="color: #666; font-size: 14px;">
                    If you didn't request this verification, please ignore this email.
                </p>

                <hr style="border: none; border-top: 1px solid #eee; margin: 30px 0;">

                <p style="color: #999; font-size: 12px;">
                    This is an automated message from IFX. Please do not reply to this email.
                </p>
            </body>
            </html>
            """;
    }

    public string BuildVerificationEmailPlainText(string userName, string code, string verificationLink, int expiryMinutes)
    {
        return $"""
            Verify Your Email Address

            Hello {userName},

            Please verify your email address using one of the following methods:

            VERIFICATION CODE: {code}

            Or click this link: {verificationLink}

            This verification link and code will expire in {expiryMinutes} minutes.

            If you didn't request this verification, please ignore this email.

            ---
            This is an automated message from IFX.
            """;
    }

    private static string EscapeHtml(string text)
    {
        return text
            .Replace("&", "&amp;")
            .Replace("<", "&lt;")
            .Replace(">", "&gt;")
            .Replace("\"", "&quot;")
            .Replace("'", "&#39;");
    }
}
