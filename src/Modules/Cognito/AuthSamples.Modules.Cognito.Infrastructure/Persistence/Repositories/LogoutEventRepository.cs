using AuthSamples.Modules.Cognito.Domain.Entities;
using AuthSamples.Modules.Cognito.Domain.Interfaces.Repositories;

namespace AuthSamples.Modules.Cognito.Infrastructure.Persistence.Repositories;

public class LogoutEventRepository : ILogoutEventRepository
{
    private readonly CognitoDbContext _context;

    public LogoutEventRepository(CognitoDbContext context)
    {
        _context = context;
    }

    public async Task AddAsync(LogoutEvent logoutEvent, CancellationToken cancellationToken = default)
    {
        await _context.LogoutEvents.AddAsync(logoutEvent, cancellationToken);
    }
}
