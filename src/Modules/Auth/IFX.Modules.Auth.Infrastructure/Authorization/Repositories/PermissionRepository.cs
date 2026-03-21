using IFX.Modules.Auth.Domain.Authorization;
using IFX.Modules.Auth.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;

namespace IFX.Modules.Auth.Infrastructure.Authorization.Repositories;

public class PermissionRepository : IPermissionRepository
{
    private readonly IfxDbContext _context;

    public PermissionRepository(IfxDbContext context)
    {
        _context = context;
    }

    public async Task<Permission?> GetByIdAsync(Guid id, CancellationToken cancellationToken = default)
        => await _context.Permissions.FirstOrDefaultAsync(p => p.Id == id, cancellationToken);

    public async Task<Permission?> GetByNameAsync(string name, CancellationToken cancellationToken = default)
        => await _context.Permissions.FirstOrDefaultAsync(p => p.Name == name, cancellationToken);

    public async Task<List<Permission>> GetAllAsync(CancellationToken cancellationToken = default)
        => await _context.Permissions.AsNoTracking().ToListAsync(cancellationToken);

    public async Task AddAsync(Permission permission, CancellationToken cancellationToken = default)
        => await _context.Permissions.AddAsync(permission, cancellationToken);

    public async Task<bool> NameExistsAsync(string name, CancellationToken cancellationToken = default)
        => await _context.Permissions.AnyAsync(p => p.Name == name, cancellationToken);

    public async Task<bool> NameExistsAsync(string name, Guid excludeId, CancellationToken cancellationToken = default)
        => await _context.Permissions.AnyAsync(p => p.Name == name && p.Id != excludeId, cancellationToken);

    public void Remove(Permission permission) => _context.Permissions.Remove(permission);
}
