namespace IFX.BuildingBlocks.Security.Authorization;

public interface ICurrentUser
{
    Guid UserId { get; }
    Guid? TenantId { get; }
    IReadOnlyCollection<string> Departments { get; }
    IReadOnlyCollection<string> Roles { get; }
    IReadOnlyCollection<string> Permissions { get; }
    IReadOnlyList<string> GlobalRoles { get; }
    bool IsGlobalAdmin { get; }
    bool MfaEnabled { get; }
    bool IsAuthenticated { get; }
}
