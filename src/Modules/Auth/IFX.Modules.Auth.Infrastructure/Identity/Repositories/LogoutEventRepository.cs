using IFX.Modules.Auth.Infrastructure.Persistence;
using IFX.Modules.Auth.Domain.Identity;
// Repository interface is in IFX.Modules.Auth.Domain.Identity

namespace IFX.Modules.Auth.Infrastructure.Identity.Repositories;

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
