using IFX.Modules.Registry.Contracts.V1;
using IFX.Modules.Transaction.Application.Ports;
using IFX.Platform.Context.Runtime.Outbound;

namespace IFX.Modules.Transaction.Infrastructure.Integrations.Outbound.Registry;

public sealed class ClassSubscriptionAvailabilityAdapter(
    OutboundContractRequestContextFactory contextFactory,
    IClassSubscriptionAvailabilityContract contract) : IClassSubscriptionAvailabilityPort
{
    public async Task<bool> IsOpenAsync(
        Guid classId,
        Guid tenantId,
        CancellationToken cancellationToken = default)
    {
        return await FailClosedContractCall.ExecuteAsync<ClassSubscriptionAvailabilityContractException>(async token =>
        {
            var context = contextFactory.CreateTenantCall(tenantId, TransactionContractConsumer.Identity);
            var response = await contract.CheckAsync(
                new ClassSubscriptionAvailabilityRequest(classId, tenantId),
                context,
                token);
            return response.IsOpen;
        }, cancellationToken);
    }
}
