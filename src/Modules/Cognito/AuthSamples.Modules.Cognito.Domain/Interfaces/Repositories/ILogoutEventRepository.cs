using AuthSamples.Modules.Cognito.Domain.Entities;

namespace AuthSamples.Modules.Cognito.Domain.Interfaces.Repositories;

public interface ILogoutEventRepository
{
    Task AddAsync(LogoutEvent logoutEvent, CancellationToken cancellationToken = default);
}
