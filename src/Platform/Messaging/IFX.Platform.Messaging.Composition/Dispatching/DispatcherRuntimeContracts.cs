namespace IFX.Platform.Messaging.Composition.Dispatching;

/// <summary>
/// Host contract implemented once per module by Plan 02 E3. Implementations must access
/// only their owning module DbContext/schema; the platform host does not provide shared storage.
/// </summary>
public interface IModuleDispatcherRuntime
{
    string ModuleId { get; }
    Task<IReadOnlyList<DispatchLease>> ClaimAsync(DispatchClaimRequest request, CancellationToken cancellationToken);
    Task<bool> RenewAsync(DispatchLease lease, DateTimeOffset leaseUntil, CancellationToken cancellationToken);
    Task<bool> CompleteAsync(DispatchLease lease, CancellationToken cancellationToken);
}

public sealed record DispatchClaimRequest(
    string LeaseOwner,
    DateTimeOffset Now,
    DateTimeOffset LeaseUntil,
    int BatchSize);

public sealed record DispatchLease(
    Guid EventId,
    string ModuleId,
    string PartitionKey,
    long Sequence,
    string LeaseOwner,
    DateTimeOffset LeaseUntil,
    byte[] ConcurrencyToken);

public sealed class DispatcherTuningOptions
{
    public int BatchSize { get; init; } = 50;
    public TimeSpan PollInterval { get; init; } = TimeSpan.FromSeconds(1);
    public TimeSpan PollJitter { get; init; } = TimeSpan.FromMilliseconds(250);
    public TimeSpan LeaseDuration { get; init; } = TimeSpan.FromMinutes(1);
    public TimeSpan RenewalInterval { get; init; } = TimeSpan.FromSeconds(20);
    public TimeSpan ClockTolerance { get; init; } = TimeSpan.FromSeconds(2);

    public void Validate()
    {
        if (BatchSize is < 1 or > 1000) throw new ArgumentOutOfRangeException(nameof(BatchSize));
        if (PollInterval <= TimeSpan.Zero || PollJitter < TimeSpan.Zero) throw new ArgumentOutOfRangeException(nameof(PollInterval));
        if (RenewalInterval <= TimeSpan.Zero || LeaseDuration <= RenewalInterval + ClockTolerance) throw new ArgumentException("Lease duration must exceed renewal interval plus clock tolerance.");
    }
}
