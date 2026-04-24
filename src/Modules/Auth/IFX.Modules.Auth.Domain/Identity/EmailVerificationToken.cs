using BaseEntity = IFX.BuildingBlocks.Domain.BaseEntity;
using IFX.Modules.Auth.Domain.Common;

namespace IFX.Modules.Auth.Domain.Identity;

public class EmailVerificationToken : BaseEntity, IAuditableEntity
{
    public Guid UserIdentityId { get; private set; }
    public string Email { get; private set; } = string.Empty;
    public string TokenHash { get; private set; } = string.Empty;
    public string Code { get; private set; } = string.Empty;
    public DateTimeOffset ExpiresAt { get; private set; }
    public bool IsUsed { get; private set; }
    public DateTimeOffset? UsedAt { get; private set; }
    public DateTimeOffset CreatedAt { get; set; }
    public DateTimeOffset UpdatedAt { get; set; }

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
            ExpiresAt = DateTimeOffset.UtcNow.Add(validityPeriod),
            IsUsed = false
        };
    }

    public bool IsValid() => !IsUsed && DateTimeOffset.UtcNow < ExpiresAt;

    public void MarkAsUsed()
    {
        IsUsed = true;
        UsedAt = DateTimeOffset.UtcNow;
    }

    public void Invalidate()
    {
        IsUsed = true;
        UsedAt = DateTimeOffset.UtcNow;
    }
}
