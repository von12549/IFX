using IFX.Modules.CRM.Contracts.V1;
using IFX.Modules.Transaction.Application.Ports;
using IFX.Platform.Context.Runtime.Outbound;

namespace IFX.Modules.Transaction.Infrastructure.Integrations.Outbound.CRM;

public sealed class AccountComplianceAdapter(
    OutboundContractRequestContextFactory contextFactory,
    IAccountComplianceContract contract) : IAccountCompliancePort
{
    public async Task<bool> IsApprovedAsync(
        Guid investmentAccountId,
        Guid tenantId,
        CancellationToken cancellationToken = default)
    {
        return await FailClosedContractCall.ExecuteAsync<AccountComplianceContractException>(async token =>
        {
            var context = contextFactory.CreateTenantCall(tenantId, TransactionContractConsumer.Identity);
            var response = await contract.CheckAsync(
                new AccountComplianceRequest(investmentAccountId, tenantId),
                context,
                token);
            return response.IsApproved;
        }, cancellationToken);
    }
}
