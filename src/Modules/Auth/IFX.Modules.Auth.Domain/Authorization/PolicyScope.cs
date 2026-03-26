namespace IFX.Modules.Auth.Domain.Authorization;

public enum PolicyScope
{
    Tenant = 0,   // Scoped to a specific tenant — TenantId required
    Platform = 1  // Platform-level default — TenantId is NULL
}
