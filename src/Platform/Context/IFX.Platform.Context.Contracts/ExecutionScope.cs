namespace IFX.Platform.Context.Contracts;

public enum ExecutionScopeKind
{
    Tenant = 1,
    Platform = 2
}

public readonly record struct TenantScope
{
    public TenantScope(Guid tenantId)
    {
        TenantId = tenantId == Guid.Empty
            ? throw new ArgumentException("TenantId cannot be empty.", nameof(tenantId))
            : tenantId;
    }

    public Guid TenantId { get; }
}

public readonly record struct PlatformScope;

public readonly record struct ExecutionScope
{
    private ExecutionScope(ExecutionScopeKind kind, Guid? tenantId)
    {
        Kind = kind;
        TenantId = tenantId;
    }

    public ExecutionScopeKind Kind { get; }

    public Guid? TenantId { get; }

    public bool IsTenant => Kind == ExecutionScopeKind.Tenant;

    public bool IsPlatform => Kind == ExecutionScopeKind.Platform;

    public static ExecutionScope ForTenant(TenantScope scope) => new(ExecutionScopeKind.Tenant, scope.TenantId);

    public static ExecutionScope ForPlatform(PlatformScope _) => new(ExecutionScopeKind.Platform, null);

    public TenantScope RequireTenant() => IsTenant && TenantId is { } tenantId
        ? new TenantScope(tenantId)
        : throw new InvalidOperationException("A tenant execution scope is required.");
}
