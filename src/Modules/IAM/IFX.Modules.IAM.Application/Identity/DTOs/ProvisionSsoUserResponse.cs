namespace IFX.Modules.IAM.Application.Identity.DTOs;

public record ProvisionSsoUserResponse
{
    public Guid UserId { get; init; }
    public Guid UserIdentityId { get; init; }
    public List<string> PermissionNames { get; init; } = [];
    public List<string> RoleNames { get; init; } = [];
    public bool WasProvisioned { get; init; }
    public bool RequiresEmailVerification { get; init; }
    public string? Email { get; init; }
}
