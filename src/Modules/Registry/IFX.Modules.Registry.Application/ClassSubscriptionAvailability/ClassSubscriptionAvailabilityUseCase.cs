using IFX.BuildingBlocks.Application.Context;
using IFX.Modules.Registry.Application.Ports;
using IFX.Platform.Context.Contracts;

namespace IFX.Modules.Registry.Application.ClassSubscriptionAvailability;

public sealed class ClassSubscriptionAvailabilityUseCase(
    IClassSubscriptionDataPort dataPort,
    IExecutionContextAccessor executionContext) : IClassSubscriptionAvailabilityUseCase
{
    public Task<bool> IsOpenAsync(Guid classId, Guid tenantId, CancellationToken cancellationToken = default)
    {
        cancellationToken.ThrowIfCancellationRequested();
        if (tenantId == Guid.Empty || !executionContext.HasCurrent ||
            executionContext.Current.Provenance != ContextProvenance.Trusted ||
            !executionContext.Current.IsTenantScope || executionContext.Current.TenantId != tenantId)
        {
            throw new InvalidOperationException("Class subscription availability requires a trusted matching tenant scope.");
        }

        return dataPort.IsClassOpenForSubscriptionAsync(classId, tenantId, cancellationToken);
    }
}
