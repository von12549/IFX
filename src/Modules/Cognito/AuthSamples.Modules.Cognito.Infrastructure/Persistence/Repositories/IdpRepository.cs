using AuthSamples.Modules.Cognito.Domain.Entities;
using AuthSamples.Modules.Cognito.Domain.Interfaces.Repositories;
using Microsoft.EntityFrameworkCore;

namespace AuthSamples.Modules.Cognito.Infrastructure.Persistence.Repositories;

public class IdpRepository : IIdpRepository
{
    private readonly CognitoDbContext _context;

    public IdpRepository(CognitoDbContext context)
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
}
