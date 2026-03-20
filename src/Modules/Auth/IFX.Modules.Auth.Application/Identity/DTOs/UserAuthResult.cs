namespace IFX.Modules.Auth.Application.Identity.DTOs;

/// <summary>
/// Result of user authentication lookup or auto-provisioning.
/// Used by claims transformation to add permission claims to authenticated principals.
/// </summary>
public record UserAuthResult
{
    public Guid UserId { get; init; }
    public List<string> PermissionNames { get; init; } = [];
    public bool WasProvisioned { get; init; }
}
