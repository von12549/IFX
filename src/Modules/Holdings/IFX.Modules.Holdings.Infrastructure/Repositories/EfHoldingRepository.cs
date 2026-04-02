using IFX.Modules.Holdings.Domain.Entities;
using IFX.Modules.Holdings.Domain.Repositories;
using IFX.Modules.Holdings.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;

namespace IFX.Modules.Holdings.Infrastructure.Repositories;

public class EfHoldingRepository : IHoldingRepository
{
    private readonly HoldingsDbContext _context;

    public EfHoldingRepository(HoldingsDbContext context) => _context = context;

    public async Task<Holding?> GetByIdAsync(Guid holdingId, CancellationToken ct = default)
        => await _context.Holdings.FirstOrDefaultAsync(h => h.Id == holdingId, ct);

    public async Task<Holding?> GetByInvestorAndClassAsync(Guid tenantId, Guid investorId, Guid classId, CancellationToken ct = default)
        => await _context.Holdings.FirstOrDefaultAsync(h => h.TenantId == tenantId && h.InvestorId == investorId && h.ClassId == classId, ct);

    public async Task<IReadOnlyList<Holding>> GetByTenantAsync(Guid tenantId, CancellationToken ct = default)
        => await _context.Holdings.Where(h => h.TenantId == tenantId).ToListAsync(ct);

    public async Task<IReadOnlyList<Holding>> GetByInvestorAsync(Guid tenantId, Guid investorId, CancellationToken ct = default)
        => await _context.Holdings.Where(h => h.TenantId == tenantId && h.InvestorId == investorId).ToListAsync(ct);

    public async Task<IReadOnlyList<Holding>> GetByClassAsync(Guid tenantId, Guid classId, CancellationToken ct = default)
        => await _context.Holdings.Where(h => h.TenantId == tenantId && h.ClassId == classId).ToListAsync(ct);

    public async Task AddAsync(Holding holding, CancellationToken ct = default)
        => await _context.Holdings.AddAsync(holding, ct);

    public void Update(Holding holding)
        => _context.Holdings.Update(holding);
}
