using IFX.Modules.IAM.Domain.Access;
using IFX.Modules.IAM.Domain.Tenancy;
using IFX.Modules.IAM.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;

namespace IFX.Modules.IAM.Infrastructure.Tenancy.Repositories;

public class TenantRepository : ITenantRepository
{
    private readonly IfxDbContext _context;

    public TenantRepository(IfxDbContext context)
    {
        _context = context;
    }

    public async Task<Tenant?> GetByIdAsync(Guid id, CancellationToken cancellationToken = default)
        => await _context.Tenants.FirstOrDefaultAsync(t => t.Id == id, cancellationToken);

    public async Task<List<Tenant>> GetAllAsync(CancellationToken cancellationToken = default)
        => await _context.Tenants.AsNoTracking().ToListAsync(cancellationToken);

    public async Task AddAsync(Tenant tenant, CancellationToken cancellationToken = default)
        => await _context.Tenants.AddAsync(tenant, cancellationToken);

    public async Task<bool> NameExistsAsync(string name, CancellationToken cancellationToken = default)
        => await _context.Tenants.AnyAsync(t => t.Name == name, cancellationToken);

    public async Task<bool> NameExistsAsync(string name, Guid excludeId, CancellationToken cancellationToken = default)
        => await _context.Tenants.AnyAsync(t => t.Name == name && t.Id != excludeId, cancellationToken);

    public void Remove(Tenant tenant) => _context.Tenants.Remove(tenant);
}
