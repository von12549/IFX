using IFX.Modules.Auth.Domain.Common;

namespace IFX.Modules.Auth.Domain.Identity;

public class EmailVerificationToken : BaseEntity, IAuditableEntity
{
    public Guid UserIdentityId { get; private set; }
    public string Email { get; private set; } = string.Empty;
    public string TokenHash { get; private set; } = string.Empty;
    public string Code { get; private set; } = string.Empty;
    public DateTime ExpiresAt { get; private set; }
    public bool IsUsed { get; private set; }
    public DateTime? UsedAt { get; private set; }
    public DateTime CreatedAt { get; set; }
    public DateTime UpdatedAt { get; set; }

    // Navigation properties
    public UserIdentity? UserIdentity { get; private set; }

    private EmailVerificationToken() { } // For EF Core

    public static EmailVerificationToken Create(
        Guid userIdentityId,
        string email,
        string tokenHash,
        string code,
        TimeSpan validityPeriod)
    {
        return new EmailVerificationToken
        {
            UserIdentityId = userIdentityId,
            Email = email,
            TokenHash = tokenHash,
            Code = code,
            ExpiresAt = DateTime.UtcNow.Add(validityPeriod),
            IsUsed = false
        };
    }

    public bool IsValid() => !IsUsed && DateTime.UtcNow < ExpiresAt;

    public void MarkAsUsed()
    {
        IsUsed = true;
        UsedAt = DateTime.UtcNow;
    }

    public void Invalidate()
    {
        IsUsed = true;
        UsedAt = DateTime.UtcNow;
    }
}
