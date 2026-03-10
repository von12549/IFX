namespace IFX.Modules.Auth.Application.DTOs;

public record ProvisionSsoUserResponse
{
    public Guid UserId { get; init; }
    public Guid UserIdentityId { get; init; }
    public string RoleName { get; init; } = string.Empty;
    public bool WasProvisioned { get; init; }
    public bool RequiresEmailVerification { get; init; }
    public string? Email { get; init; }
}
