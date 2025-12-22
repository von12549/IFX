using AuthSamples.Modules.Cognito.Domain.Entities;
using AuthSamples.Modules.Cognito.Domain.Interfaces.Repositories;
using Microsoft.EntityFrameworkCore;

namespace AuthSamples.Modules.Cognito.Infrastructure.Persistence.Repositories;

public class UserActivityLogRepository : IUserActivityLogRepository
{
    private readonly CognitoDbContext _context;

    public UserActivityLogRepository(CognitoDbContext context)
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
