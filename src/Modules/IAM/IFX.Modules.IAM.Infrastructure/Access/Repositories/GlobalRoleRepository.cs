using IFX.Modules.IAM.Domain.Access;
using IFX.Modules.IAM.Domain.Tenancy;
using IFX.Modules.IAM.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;

namespace IFX.Modules.IAM.Infrastructure.Access.Repositories;

public class GlobalRoleRepository : IGlobalRoleRepository
{
    private readonly IfxDbContext _context;

    public GlobalRoleRepository(IfxDbContext context)
    {
        _context = context;
    }

    public async Task<GlobalRole?> GetByIdAsync(Guid id, CancellationToken ct = default)
        => await _context.GlobalRoles.FirstOrDefaultAsync(gr => gr.Id == id, ct);

    public async Task<GlobalRole?> GetByNameAsync(string name, CancellationToken ct = default)
        => await _context.GlobalRoles.FirstOrDefaultAsync(gr => gr.Name == name, ct);

    public async Task<IReadOnlyList<GlobalRole>> GetAllAsync(CancellationToken ct = default)
        => await _context.GlobalRoles.AsNoTracking().ToListAsync(ct);

    public async Task<IReadOnlyList<GlobalRole>> GetByUserIdAsync(Guid userId, CancellationToken ct = default)
        => await _context.GlobalRoles
            .AsNoTracking()
            .Where(gr => gr.UserGlobalRoles.Any(ugr => ugr.UserId == userId))
            .ToListAsync(ct);

    public async Task AddAsync(GlobalRole role, CancellationToken ct = default)
        => await _context.GlobalRoles.AddAsync(role, ct);

    public async Task<UserGlobalRole?> GetUserGlobalRoleAsync(
        Guid userId, Guid globalRoleId, CancellationToken ct = default)
        => await _context.UserGlobalRoles
            .FirstOrDefaultAsync(ugr => ugr.UserId == userId && ugr.GlobalRoleId == globalRoleId, ct);

    public async Task AddUserGlobalRoleAsync(UserGlobalRole userGlobalRole, CancellationToken ct = default)
        => await _context.UserGlobalRoles.AddAsync(userGlobalRole, ct);

    public void RemoveUserGlobalRole(UserGlobalRole userGlobalRole)
        => _context.UserGlobalRoles.Remove(userGlobalRole);

    public async Task<int> CountPlatformAdminsAsync(CancellationToken ct = default)
        => await _context.UserGlobalRoles
            .CountAsync(ugr => ugr.GlobalRole.Name == GlobalRoleNames.PlatformAdmin, ct);
}
