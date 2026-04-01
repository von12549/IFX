using IFX.Modules.Registry.Abstractions.DTOs;
using IFX.Modules.Registry.Abstractions.Interfaces;
using IFX.Modules.Registry.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;

namespace IFX.Modules.Registry.Infrastructure.Services;

public class RegistryReader : IRegistryReader
{
    private readonly RegistryDbContext _context;

    public RegistryReader(RegistryDbContext context)
    {
        _context = context;
    }

    public async Task<FundSummaryDto?> GetFundByIdAsync(Guid fundId, Guid tenantId, CancellationToken ct = default)
    {
        var fund = await _context.Funds
            .FirstOrDefaultAsync(f => f.Id == fundId && f.TenantId == tenantId, ct);

        if (fund == null)
            return null;

        return new FundSummaryDto(
            fund.Id,
            fund.FundCode,
            fund.FundName,
            fund.FundType.ToString(),
            fund.BaseCurrency,
            fund.Status.ToString());
    }

    public async Task<ClassSummaryDto?> GetClassByIdAsync(Guid classId, Guid tenantId, CancellationToken ct = default)
    {
        var fundClass = await _context.FundClasses
            .FirstOrDefaultAsync(fc => fc.Id == classId && fc.TenantId == tenantId, ct);

        if (fundClass == null)
            return null;

        return new ClassSummaryDto(
            fundClass.Id,
            fundClass.FundId,
            fundClass.ClassCode,
            fundClass.ClassName,
            fundClass.Currency,
            fundClass.NavFrequency.ToString(),
            fundClass.Status.ToString(),
            fundClass.IsOpenForSubscription());
    }

    public async Task<bool> IsClassOpenForSubscriptionAsync(Guid classId, Guid tenantId, CancellationToken ct = default)
    {
        var fundClass = await _context.FundClasses
            .FirstOrDefaultAsync(fc => fc.Id == classId && fc.TenantId == tenantId, ct);

        return fundClass?.IsOpenForSubscription() ?? false;
    }

    public async Task<bool> FundExistsAsync(Guid fundId, Guid tenantId, CancellationToken ct = default)
    {
        return await _context.Funds
            .AnyAsync(f => f.Id == fundId && f.TenantId == tenantId, ct);
    }
}
