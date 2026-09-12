using IFX.Modules.IAM.Infrastructure.Persistence;
using IFX.Modules.IAM.Domain.Identity;
// Repository interface is in IFX.Modules.IAM.Domain.Identity

namespace IFX.Modules.IAM.Infrastructure.Identity.Repositories;

public class LogoutEventRepository : ILogoutEventRepository
{
    private readonly IfxDbContext _context;

    public LogoutEventRepository(IfxDbContext context)
    {
        _context = context;
    }

    public async Task AddAsync(LogoutEvent logoutEvent, CancellationToken cancellationToken = default)
    {
        await _context.LogoutEvents.AddAsync(logoutEvent, cancellationToken);
    }
}
