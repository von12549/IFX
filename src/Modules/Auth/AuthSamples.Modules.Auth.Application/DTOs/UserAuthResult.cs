namespace AuthSamples.Modules.Auth.Application.DTOs;

/// <summary>
/// Result of user authentication lookup or auto-provisioning.
/// Used by claims transformation to add role claims to authenticated principals.
/// </summary>
public record UserAuthResult
{
    public Guid UserId { get; init; }
    public string RoleName { get; init; } = string.Empty;
    public bool WasProvisioned { get; init; }
}
