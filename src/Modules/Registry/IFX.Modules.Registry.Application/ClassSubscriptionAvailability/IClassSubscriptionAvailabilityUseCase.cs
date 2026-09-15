namespace IFX.Modules.Registry.Application.ClassSubscriptionAvailability;

public interface IClassSubscriptionAvailabilityUseCase
{
    Task<bool> IsOpenAsync(Guid classId, Guid tenantId, CancellationToken cancellationToken = default);
}
