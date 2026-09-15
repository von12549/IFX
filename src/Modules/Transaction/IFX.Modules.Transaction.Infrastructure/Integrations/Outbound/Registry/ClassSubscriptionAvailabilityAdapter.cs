using IFX.BuildingBlocks.Application.Context;
using IFX.Modules.Registry.Contracts.V1;
using IFX.Modules.Transaction.Application.Ports;

namespace IFX.Modules.Transaction.Infrastructure.Integrations.Outbound.Registry;

public sealed class ClassSubscriptionAvailabilityAdapter(
    IExecutionContextAccessor executionContextAccessor,
    IClassSubscriptionAvailabilityContract contract) : IClassSubscriptionAvailabilityPort
{
    public async Task<bool> IsOpenAsync(
        Guid classId,
        Guid tenantId,
        CancellationToken cancellationToken = default)
    {
        try
        {
            var context = ContractRequestContextFactory.Create(executionContextAccessor, tenantId);
            var response = await contract.CheckAsync(
                new ClassSubscriptionAvailabilityRequest(classId, tenantId),
                context,
                cancellationToken);
            return response.IsOpen;
        }
        catch (OperationCanceledException) when (cancellationToken.IsCancellationRequested)
        {
            throw;
        }
        catch (TimeoutException)
        {
            return false;
        }
        catch (ClassSubscriptionAvailabilityContractException)
        {
            return false;
        }
        catch (InvalidOperationException exception) when (exception.Message.StartsWith("contract_", StringComparison.Ordinal))
        {
            return false;
        }
    }
}
