using IFX.BuildingBlocks.Application.Context;
using IFX.Modules.CRM.Contracts.V1;
using IFX.Modules.Transaction.Application.Ports;

namespace IFX.Modules.Transaction.Infrastructure.Integrations.CRM;

public sealed class AccountComplianceAdapter(
    IExecutionContextAccessor executionContextAccessor,
    IAccountComplianceContract contract) : IAccountCompliancePort
{
    public async Task<bool> IsApprovedAsync(
        Guid investmentAccountId,
        Guid tenantId,
        CancellationToken cancellationToken = default)
    {
        try
        {
            var context = ContractRequestContextFactory.Create(executionContextAccessor, tenantId);
            var response = await contract.CheckAsync(
                new AccountComplianceRequest(investmentAccountId, tenantId),
                context,
                cancellationToken);
            return response.IsApproved;
        }
        catch (OperationCanceledException) when (cancellationToken.IsCancellationRequested)
        {
            throw;
        }
        catch (TimeoutException)
        {
            return false;
        }
        catch (AccountComplianceContractException)
        {
            return false;
        }
        catch (InvalidOperationException exception) when (exception.Message.StartsWith("contract_", StringComparison.Ordinal))
        {
            return false;
        }
    }
}
