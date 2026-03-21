using IFX.Modules.Auth.Domain.Authorization;
using IFX.Modules.Auth.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;

namespace IFX.Modules.Auth.Infrastructure.Authorization.Repositories;

public class RoleGroupRepository : IRoleGroupRepository
{
    private readonly IfxDbContext _context;

    public RoleGroupRepository(IfxDbContext context)
    {
        _context = context;
    }

    public async Task<RoleGroup?> GetByIdAsync(Guid id, CancellationToken cancellationToken = default)
        => await _context.RoleGroups.FirstOrDefaultAsync(g => g.Id == id, cancellationToken);

    public async Task<RoleGroup?> GetByNameAsync(string name, CancellationToken cancellationToken = default)
        => await _context.RoleGroups.FirstOrDefaultAsync(g => g.Name == name, cancellationToken);

    public async Task<RoleGroup?> GetByIdWithRolesAsync(Guid id, CancellationToken cancellationToken = default)
        => await _context.RoleGroups
            .Include(g => g.Roles)
            .FirstOrDefaultAsync(g => g.Id == id, cancellationToken);

    public async Task<List<RoleGroup>> GetAllAsync(CancellationToken cancellationToken = default)
        => await _context.RoleGroups
            .Include(g => g.Roles)
            .AsNoTracking()
            .ToListAsync(cancellationToken);

    public async Task AddAsync(RoleGroup group, CancellationToken cancellationToken = default)
        => await _context.RoleGroups.AddAsync(group, cancellationToken);

    public async Task<bool> NameExistsAsync(string name, CancellationToken cancellationToken = default)
        => await _context.RoleGroups.AnyAsync(g => g.Name == name, cancellationToken);

    public async Task<bool> NameExistsAsync(string name, Guid excludeId, CancellationToken cancellationToken = default)
        => await _context.RoleGroups.AnyAsync(g => g.Name == name && g.Id != excludeId, cancellationToken);

    public void Remove(RoleGroup group) => _context.RoleGroups.Remove(group);
}
