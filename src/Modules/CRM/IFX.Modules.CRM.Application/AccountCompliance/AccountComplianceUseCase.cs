using IFX.BuildingBlocks.Application.Context;
using IFX.Modules.CRM.Application.Ports;
using IFX.Platform.Context.Contracts;

namespace IFX.Modules.CRM.Application.AccountCompliance;

public sealed class AccountComplianceUseCase(
    IAccountComplianceDataPort dataPort,
    IExecutionContextAccessor executionContext) : IAccountComplianceUseCase
{
    public Task<bool> IsApprovedAsync(
        Guid investmentAccountId,
        Guid tenantId,
        CancellationToken cancellationToken = default)
    {
        cancellationToken.ThrowIfCancellationRequested();
        if (tenantId == Guid.Empty || !executionContext.HasCurrent ||
            executionContext.Current.Provenance != ContextProvenance.Trusted ||
            !executionContext.Current.IsTenantScope || executionContext.Current.TenantId != tenantId)
        {
            throw new InvalidOperationException("Account compliance requires a trusted matching tenant scope.");
        }

        return dataPort.IsInvestmentAccountKycApprovedAsync(investmentAccountId, tenantId, cancellationToken);
    }
}
