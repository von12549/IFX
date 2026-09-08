using IFX.Modules.CRM.Application.Ports;
using IFX.Modules.CRM.Domain.Enums;
using IFX.Modules.CRM.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;

namespace IFX.Modules.CRM.Infrastructure.Integrations;

public sealed class AccountComplianceDataAdapter(CrmDbContext context) : IAccountComplianceDataPort
{
    public async Task<bool> IsInvestmentAccountKycApprovedAsync(
        Guid investmentAccountId,
        Guid tenantId,
        CancellationToken cancellationToken = default)
    {
        var linkedPartyIds = await context.PartyInvestmentAccountLinks
            .Where(link => link.InvestmentAccountId == investmentAccountId &&
                           link.TenantId == tenantId &&
                           link.ExpiryDate == null)
            .Select(link => link.PartyId)
            .ToListAsync(cancellationToken);

        if (linkedPartyIds.Count == 0)
        {
            return false;
        }

        return await context.Investors.AnyAsync(
            investor => investor.TenantId == tenantId &&
                        investor.PartyId.HasValue &&
                        linkedPartyIds.Contains(investor.PartyId.Value) &&
                        investor.KycStatus == KycStatus.Approved,
            cancellationToken);
    }
}
