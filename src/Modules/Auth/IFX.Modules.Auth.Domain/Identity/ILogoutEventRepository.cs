using IFX.Modules.Auth.Domain.Entities;

namespace IFX.Modules.Auth.Domain.Interfaces.Repositories;

public interface ILogoutEventRepository
{
    Task AddAsync(LogoutEvent logoutEvent, CancellationToken cancellationToken = default);
}
