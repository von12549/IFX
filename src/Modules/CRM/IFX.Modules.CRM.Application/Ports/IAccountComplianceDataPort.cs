namespace IFX.Modules.CRM.Application.Ports;

public interface IAccountComplianceDataPort
{
    Task<bool> IsInvestmentAccountKycApprovedAsync(
        Guid investmentAccountId,
        Guid tenantId,
        CancellationToken cancellationToken = default);
}
