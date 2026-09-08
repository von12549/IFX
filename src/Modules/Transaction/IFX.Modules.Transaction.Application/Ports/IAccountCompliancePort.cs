namespace IFX.Modules.Transaction.Application.Ports;

public interface IAccountCompliancePort
{
    Task<bool> IsApprovedAsync(
        Guid investmentAccountId,
        Guid tenantId,
        CancellationToken cancellationToken = default);
}
