namespace IFX.BuildingBlocks.Application.Commands;

/// <summary>
/// Stable, module-local identity used to reconcile a retryable command after a duplicate request
/// or an unknown commit outcome.
/// </summary>
public sealed record IdempotencyIdentity(Guid TenantId, string CommandType, string Key)
{
    public static IdempotencyIdentity For<TCommand>(Guid tenantId, string key)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(key);
        return new IdempotencyIdentity(
            tenantId,
            typeof(TCommand).FullName ?? typeof(TCommand).Name,
            key);
    }
}

public static class IdempotencyPolicy
{
    /// <summary>
    /// A module may retain records longer, but never shorter than this reconciliation window.
    /// </summary>
    public static TimeSpan MinimumRetention { get; } = TimeSpan.FromDays(7);
}
