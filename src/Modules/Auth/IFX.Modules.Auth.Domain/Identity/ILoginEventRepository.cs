// Types are in same namespace (IFX.Modules.Auth.Domain.Identity)

namespace IFX.Modules.Auth.Domain.Identity;

public interface ILoginEventRepository
{
    Task AddAsync(LoginEvent loginEvent, CancellationToken cancellationToken = default);
    Task<IEnumerable<LoginEvent>> GetUserLoginHistoryAsync(Guid userId, int pageNumber, int pageSize, CancellationToken cancellationToken = default);
    Task<int> GetUserLoginCountAsync(Guid userId, CancellationToken cancellationToken = default);
}
