using IFX.Modules.Auth.Infrastructure.Persistence;
using IFX.Modules.Auth.Domain.Identity;
// Repository interface is in IFX.Modules.Auth.Domain.Identity
using Microsoft.EntityFrameworkCore;

namespace IFX.Modules.Auth.Infrastructure.Identity.Repositories;

public class IdpRepository : IIdpRepository
{
    private readonly IfxDbContext _context;

    public IdpRepository(IfxDbContext context)
    {
        _context = context;
    }

    public async Task<Idp?> GetByIdAsync(Guid id, CancellationToken cancellationToken = default)
    {
        return await _context.Idps
            .FirstOrDefaultAsync(i => i.Id == id, cancellationToken);
    }

    public async Task<Idp?> GetByIssuerAsync(string issuer, CancellationToken cancellationToken = default)
    {
        return await _context.Idps
            .FirstOrDefaultAsync(i => i.Issuer == issuer, cancellationToken);
    }

    public async Task<List<Idp>> GetAllAsync(CancellationToken cancellationToken = default)
    {
        return await _context.Idps
            .OrderBy(i => i.Name)
            .ToListAsync(cancellationToken);
    }

    public async Task<List<Idp>> GetEnabledAsync(CancellationToken cancellationToken = default)
    {
        return await _context.Idps
            .Where(i => i.Enabled)
            .OrderBy(i => i.Name)
            .ToListAsync(cancellationToken);
    }

    public async Task<Idp?> GetEnabledByIssuerAsync(string issuer, CancellationToken cancellationToken = default)
    {
        return await _context.Idps
            .AsNoTracking()
            .Where(i => i.Issuer == issuer && i.Enabled)
            .FirstOrDefaultAsync(cancellationToken);
    }

    public async Task AddAsync(Idp idp, CancellationToken cancellationToken = default)
    {
        await _context.Idps.AddAsync(idp, cancellationToken);
    }

    public async Task<bool> IssuerExistsAsync(string issuer, CancellationToken cancellationToken = default)
    {
        return await _context.Idps
            .AnyAsync(i => i.Issuer == issuer, cancellationToken);
    }

    public async Task<bool> IssuerExistsAsync(string issuer, Guid excludeIdpId, CancellationToken cancellationToken = default)
    {
        return await _context.Idps
            .AnyAsync(i => i.Issuer == issuer && i.Id != excludeIdpId, cancellationToken);
    }

    public async Task<Idp?> GetPrimaryIdpAsync(CancellationToken cancellationToken = default)
    {
        return await _context.Idps
            .FirstOrDefaultAsync(i => i.IsPrimary && i.Enabled, cancellationToken);
    }

    public async Task ClearPrimaryFlagAsync(CancellationToken cancellationToken = default)
    {
        await _context.Idps
            .Where(i => i.IsPrimary)
            .ExecuteUpdateAsync(s => s.SetProperty(i => i.IsPrimary, false), cancellationToken);
    }
}
