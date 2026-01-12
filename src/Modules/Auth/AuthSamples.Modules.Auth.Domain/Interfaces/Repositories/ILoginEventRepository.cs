using AuthSamples.Modules.Auth.Domain.Entities;

namespace AuthSamples.Modules.Auth.Domain.Interfaces.Repositories;

public interface ILoginEventRepository
{
    Task AddAsync(LoginEvent loginEvent, CancellationToken cancellationToken = default);
    Task<IEnumerable<LoginEvent>> GetUserLoginHistoryAsync(Guid userId, int pageNumber, int pageSize, CancellationToken cancellationToken = default);
    Task<int> GetUserLoginCountAsync(Guid userId, CancellationToken cancellationToken = default);
}
