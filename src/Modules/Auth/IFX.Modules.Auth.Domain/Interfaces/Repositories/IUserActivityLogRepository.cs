using IFX.Modules.Auth.Domain.Entities;

namespace IFX.Modules.Auth.Domain.Interfaces.Repositories;

public interface IUserActivityLogRepository
{
    Task AddAsync(UserActivityLog activityLog, CancellationToken cancellationToken = default);
    Task<IEnumerable<UserActivityLog>> GetUserActivitiesAsync(Guid userId, int pageNumber, int pageSize, CancellationToken cancellationToken = default);
    Task<int> GetUserActivityCountAsync(Guid userId, CancellationToken cancellationToken = default);
}
