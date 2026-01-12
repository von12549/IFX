using AuthSamples.Modules.Auth.Domain.Entities;

namespace AuthSamples.Modules.Auth.Domain.Interfaces.Repositories;

public interface ILogoutEventRepository
{
    Task AddAsync(LogoutEvent logoutEvent, CancellationToken cancellationToken = default);
}
