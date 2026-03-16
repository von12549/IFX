using IFX.Modules.Auth.Infrastructure.Persistence;
using IFX.Modules.Auth.Domain.Identity;
// Repository interface is in IFX.Modules.Auth.Domain.Identity
using Microsoft.EntityFrameworkCore;

namespace IFX.Modules.Auth.Infrastructure.Identity.Repositories;

public class LoginEventRepository : ILoginEventRepository
{
    private readonly AuthDbContext _context;

    public LoginEventRepository(AuthDbContext context)
    {
        _context = context;
    }

    public async Task AddAsync(LoginEvent loginEvent, CancellationToken cancellationToken = default)
    {
        await _context.LoginEvents.AddAsync(loginEvent, cancellationToken);
    }

    public async Task<IEnumerable<LoginEvent>> GetUserLoginHistoryAsync(
        Guid userId,
        int pageNumber,
        int pageSize,
        CancellationToken cancellationToken = default)
    {
        return await _context.LoginEvents
            .Where(le => le.UserId == userId)
            .OrderByDescending(le => le.LoginTimestamp)
            .Skip((pageNumber - 1) * pageSize)
            .Take(pageSize)
            .AsNoTracking()
            .ToListAsync(cancellationToken);
    }

    public async Task<int> GetUserLoginCountAsync(Guid userId, CancellationToken cancellationToken = default)
    {
        return await _context.LoginEvents
            .Where(le => le.UserId == userId)
            .CountAsync(cancellationToken);
    }
}
