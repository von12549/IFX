using AuthSamples.Modules.Auth.Domain.Entities;
using AuthSamples.Modules.Auth.Domain.Interfaces.Repositories;

namespace AuthSamples.Modules.Auth.Infrastructure.Persistence.Repositories;

public class LogoutEventRepository : ILogoutEventRepository
{
    private readonly AuthDbContext _context;

    public LogoutEventRepository(AuthDbContext context)
    {
        _context = context;
    }

    public async Task AddAsync(LogoutEvent logoutEvent, CancellationToken cancellationToken = default)
    {
        await _context.LogoutEvents.AddAsync(logoutEvent, cancellationToken);
    }
}
