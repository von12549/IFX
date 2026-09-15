namespace IFX.Modules.CRM.Application.AccountCompliance;

public interface IAccountComplianceUseCase
{
    Task<bool> IsApprovedAsync(Guid investmentAccountId, Guid tenantId, CancellationToken cancellationToken = default);
}
