using AuthSamples.Modules.Cognito.Domain.Entities;
using AuthSamples.Modules.Cognito.Domain.Interfaces.Repositories;
using Microsoft.EntityFrameworkCore;

namespace AuthSamples.Modules.Cognito.Infrastructure.Persistence.Repositories;

public class LoginEventRepository : ILoginEventRepository
{
    private readonly CognitoDbContext _context;

    public LoginEventRepository(CognitoDbContext context)
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
