using AutoMapper;
using IFX.Modules.Holdings.Abstractions.DTOs;
using IFX.Modules.Holdings.Abstractions.Interfaces;
using IFX.Modules.Holdings.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;

namespace IFX.Modules.Holdings.Infrastructure.Services;

public class HoldingsReader : IHoldingsReader
{
    private readonly HoldingsDbContext _context;
    private readonly IMapper _mapper;

    public HoldingsReader(HoldingsDbContext context, IMapper mapper)
    {
        _context = context;
        _mapper = mapper;
    }

    public async Task<HoldingSummaryDto?> GetHoldingByIdAsync(Guid holdingId, CancellationToken ct = default)
    {
        var holding = await _context.Holdings.FirstOrDefaultAsync(h => h.Id == holdingId, ct);
        return holding == null ? null : _mapper.Map<HoldingSummaryDto>(holding);
    }

    public async Task<IReadOnlyList<HoldingSummaryDto>> GetHoldingsByInvestmentAccountAsync(Guid tenantId, Guid investmentAccountId, CancellationToken ct = default)
    {
        var holdings = await _context.Holdings.Where(h => h.TenantId == tenantId && h.InvestmentAccountId == investmentAccountId).ToListAsync(ct);
        return _mapper.Map<IReadOnlyList<HoldingSummaryDto>>(holdings);
    }

    public async Task<IReadOnlyList<HoldingSummaryDto>> GetHoldingsByClassAsync(Guid tenantId, Guid classId, CancellationToken ct = default)
    {
        var holdings = await _context.Holdings.Where(h => h.TenantId == tenantId && h.ClassId == classId).ToListAsync(ct);
        return _mapper.Map<IReadOnlyList<HoldingSummaryDto>>(holdings);
    }
}
