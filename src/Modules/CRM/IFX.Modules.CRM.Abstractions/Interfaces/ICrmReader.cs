using IFX.Modules.CRM.Abstractions.DTOs;

namespace IFX.Modules.CRM.Abstractions.Interfaces;

public interface ICrmReader
{
    Task<PartySummaryDto?> GetPartyByIdAsync(Guid partyId, Guid tenantId, CancellationToken ct = default);
    Task<InvestorSummaryDto?> GetInvestorByIdAsync(Guid investorId, Guid tenantId, CancellationToken ct = default);
    Task<bool> IsInvestorKycApprovedAsync(Guid investorId, Guid tenantId, CancellationToken ct = default);
    Task<bool> IsInvestmentAccountKycApprovedAsync(Guid investmentAccountId, Guid tenantId, CancellationToken ct = default);
    Task<bool> PartyExistsAsync(Guid partyId, Guid tenantId, CancellationToken ct = default);
}
