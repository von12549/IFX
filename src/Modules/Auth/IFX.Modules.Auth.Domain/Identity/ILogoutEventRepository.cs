// Types are in same namespace (IFX.Modules.Auth.Domain.Identity)

namespace IFX.Modules.Auth.Domain.Identity;

public interface ILogoutEventRepository
{
    Task AddAsync(LogoutEvent logoutEvent, CancellationToken cancellationToken = default);
}
