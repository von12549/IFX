namespace AuthSamples.Modules.Auth.Application.DTOs;

public record ProvisionSsoUserResponse
{
    public Guid UserId { get; init; }
    public string RoleName { get; init; } = string.Empty;
    public bool WasProvisioned { get; init; }
}
