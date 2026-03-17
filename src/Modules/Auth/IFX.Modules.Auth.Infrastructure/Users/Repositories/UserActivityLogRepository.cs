using IFX.Modules.Auth.Infrastructure.Persistence;
using IFX.Modules.Auth.Domain.Users;
// Repository interface is in same namespace (IFX.Modules.Auth.Domain.Users)
using Microsoft.EntityFrameworkCore;

namespace IFX.Modules.Auth.Infrastructure.Users.Repositories;

public class UserActivityLogRepository : IUserActivityLogRepository
{
    private readonly IfxDbContext _context;

    public UserActivityLogRepository(IfxDbContext context)
    {
        _context = context;
    }

    public async Task AddAsync(UserActivityLog activityLog, CancellationToken cancellationToken = default)
    {
        await _context.UserActivityLogs.AddAsync(activityLog, cancellationToken);
    }

    public async Task<IEnumerable<UserActivityLog>> GetUserActivitiesAsync(
        Guid userId,
        int pageNumber,
        int pageSize,
        CancellationToken cancellationToken = default)
    {
        return await _context.UserActivityLogs
            .Where(ual => ual.UserId == userId)
            .OrderByDescending(ual => ual.Timestamp)
            .Skip((pageNumber - 1) * pageSize)
            .Take(pageSize)
            .AsNoTracking()
            .ToListAsync(cancellationToken);
    }

    public async Task<int> GetUserActivityCountAsync(Guid userId, CancellationToken cancellationToken = default)
    {
        return await _context.UserActivityLogs
            .Where(ual => ual.UserId == userId)
            .CountAsync(cancellationToken);
    }
}
