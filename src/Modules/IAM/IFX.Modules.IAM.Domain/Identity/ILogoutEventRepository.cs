// Types are in same namespace (IFX.Modules.IAM.Domain.Identity)

namespace IFX.Modules.IAM.Domain.Identity;

public interface ILogoutEventRepository
{
    Task AddAsync(LogoutEvent logoutEvent, CancellationToken cancellationToken = default);
}
