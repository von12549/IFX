namespace IFX.Modules.Transaction.Application.Ports;

public interface IClassSubscriptionAvailabilityPort
{
    Task<bool> IsOpenAsync(
        Guid classId,
        Guid tenantId,
        CancellationToken cancellationToken = default);
}
