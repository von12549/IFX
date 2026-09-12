using IFX.Modules.IAM.Domain.Users;

namespace IFX.Modules.IAM.Domain.Access;

public class UserGlobalRole
{
    public Guid UserId { get; private set; }
    public Guid GlobalRoleId { get; private set; }
    public User User { get; private set; } = null!;
    public GlobalRole GlobalRole { get; private set; } = null!;
    public DateTimeOffset AssignedAt { get; private set; }

    private UserGlobalRole() { } // EF Core

    public static UserGlobalRole Create(Guid userId, Guid globalRoleId)
    {
        if (userId == Guid.Empty)
            throw new ArgumentException("UserId must not be empty.", nameof(userId));
        if (globalRoleId == Guid.Empty)
            throw new ArgumentException("GlobalRoleId must not be empty.", nameof(globalRoleId));

        return new UserGlobalRole
        {
            UserId = userId,
            GlobalRoleId = globalRoleId,
            AssignedAt = DateTimeOffset.UtcNow
        };
    }
}
