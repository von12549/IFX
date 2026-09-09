using IFX.Modules.CRM.Domain.Entities;
using IFX.Modules.CRM.Domain.Repositories;
using IFX.Modules.CRM.Infrastructure.Persistence;
using IFX.BuildingBlocks.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore;

namespace IFX.Modules.CRM.Infrastructure.Repositories;

public class EfInvestmentAccountRepository : IInvestmentAccountRepository
{
    private readonly CrmDbContext _context;

    public EfInvestmentAccountRepository(CrmDbContext context) => _context = context;

    public async Task<InvestmentAccount?> GetByIdAsync(Guid id, Guid tenantId, CancellationToken ct = default)
    {
        TenantQueryGuard.Require(tenantId);
        return await _context.InvestmentAccounts
            .Include(a => a.PartyLinks)
            .Include(a => a.AdvisorLinks)
            .FirstOrDefaultAsync(a => a.Id == id && a.TenantId == tenantId, ct);
    }

    public async Task<IReadOnlyList<InvestmentAccount>> GetByTenantAsync(Guid tenantId, CancellationToken ct = default)
    {
        TenantQueryGuard.Require(tenantId);
        return await _context.InvestmentAccounts
            .Where(a => a.TenantId == tenantId)
            .OrderBy(a => a.AccountNumber)
            .ToListAsync(ct);
    }

    public async Task<bool> AccountNumberExistsAsync(string accountNumber, Guid tenantId, CancellationToken ct = default)
    {
        TenantQueryGuard.Require(tenantId);
        return await _context.InvestmentAccounts
            .AnyAsync(a => a.AccountNumber == accountNumber && a.TenantId == tenantId, ct);
    }

    public async Task<bool> AccountNumberExistsAsync(string accountNumber, Guid tenantId, Guid excludeId, CancellationToken ct = default)
    {
        TenantQueryGuard.Require(tenantId);
        return await _context.InvestmentAccounts
            .AnyAsync(a => a.AccountNumber == accountNumber && a.TenantId == tenantId && a.Id != excludeId, ct);
    }

    public async Task AddAsync(InvestmentAccount account, CancellationToken ct = default)
    {
        await _context.InvestmentAccounts.AddAsync(account, ct);
    }

    public void Update(InvestmentAccount account)
    {
        _context.InvestmentAccounts.Update(account);
    }
}
