namespace IFX.Modules.Auth.Application.Identity.DTOs;

/// <summary>
/// Result of user authentication lookup or auto-provisioning.
/// Used by claims transformation to add permission and tenant claims to authenticated principals.
/// </summary>
public record UserAuthResult
{
    public Guid UserId { get; init; }
    public Guid? PrimaryTenantId { get; init; }
    public List<string> PermissionNames { get; init; } = [];
    public List<string> RoleNames { get; init; } = [];
    public List<string> DepartmentNames { get; init; } = [];
    public bool WasProvisioned { get; init; }
}
