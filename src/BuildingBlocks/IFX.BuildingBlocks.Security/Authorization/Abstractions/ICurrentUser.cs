namespace IFX.BuildingBlocks.Security.Authorization.Abstractions;

public interface ICurrentUser
{
    Guid UserId { get; }
    Guid? TenantId { get; }
    IReadOnlyCollection<string> Departments { get; }
    IReadOnlyCollection<string> Roles { get; }
    IReadOnlyCollection<string> Permissions { get; }
    bool MfaEnabled { get; }
    bool IsAuthenticated { get; }
}
