namespace IFX.Modules.Registry.Application.Ports;

public interface IClassSubscriptionDataPort
{
    Task<bool> IsClassOpenForSubscriptionAsync(
        Guid classId,
        Guid tenantId,
        CancellationToken cancellationToken = default);
}
