using IFX.Modules.CRM.Abstractions.DTOs;
using IFX.Modules.CRM.Abstractions.Interfaces;
using IFX.Modules.CRM.Domain.Enums;
using IFX.Modules.CRM.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;

namespace IFX.Modules.CRM.Infrastructure.Services;

public class CrmReader : ICrmReader
{
    private readonly CrmDbContext _context;

    public CrmReader(CrmDbContext context)
    {
        _context = context;
    }

    public async Task<PartySummaryDto?> GetPartyByIdAsync(Guid partyId, Guid tenantId, CancellationToken ct = default)
    {
        var party = await _context.Parties
            .FirstOrDefaultAsync(p => p.Id == partyId && p.TenantId == tenantId, ct);

        if (party == null) return null;

        return new PartySummaryDto(
            party.Id,
            party.PartyCode,
            party.Name,
            party.LegalStructure.ToString(),
            party.Status.ToString());
    }

    public async Task<InvestorSummaryDto?> GetInvestorByIdAsync(Guid investorId, Guid tenantId, CancellationToken ct = default)
    {
        var investor = await _context.Investors
            .FirstOrDefaultAsync(i => i.Id == investorId && i.TenantId == tenantId, ct);

        if (investor == null) return null;

        return new InvestorSummaryDto(
            investor.Id,
            investor.InvestorCode,
            investor.Name,
            investor.LegalStructure.ToString(),
            investor.KycStatus.ToString(),
            investor.TaxResidencyCountry,
            investor.Status.ToString());
    }

    public async Task<bool> IsInvestorKycApprovedAsync(Guid investorId, Guid tenantId, CancellationToken ct = default)
    {
        return await _context.Investors
            .AnyAsync(i => i.Id == investorId && i.TenantId == tenantId && i.KycStatus == KycStatus.Approved, ct);
    }

    public async Task<bool> IsInvestmentAccountKycApprovedAsync(Guid investmentAccountId, Guid tenantId, CancellationToken ct = default)
    {
        // Get all party IDs linked to this account with active links (no expiry)
        var linkedPartyIds = await _context.PartyInvestmentAccountLinks
            .Where(l => l.InvestmentAccountId == investmentAccountId
                     && l.TenantId == tenantId
                     && l.ExpiryDate == null)
            .Select(l => l.PartyId)
            .ToListAsync(ct);

        if (!linkedPartyIds.Any()) return false;

        // Check if any investor linked to these parties has approved KYC
        return await _context.Investors
            .AnyAsync(i => i.TenantId == tenantId
                        && i.PartyId.HasValue
                        && linkedPartyIds.Contains(i.PartyId.Value)
                        && i.KycStatus == KycStatus.Approved, ct);
    }

    public async Task<bool> PartyExistsAsync(Guid partyId, Guid tenantId, CancellationToken ct = default)
    {
        return await _context.Parties
            .AnyAsync(p => p.Id == partyId && p.TenantId == tenantId, ct);
    }
}
