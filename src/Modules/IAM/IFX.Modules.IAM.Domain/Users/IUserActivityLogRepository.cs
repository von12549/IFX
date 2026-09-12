// UserActivityLog is in same namespace (IFX.Modules.IAM.Domain.Users)

namespace IFX.Modules.IAM.Domain.Users;

public interface IUserActivityLogRepository
{
    Task AddAsync(UserActivityLog activityLog, CancellationToken cancellationToken = default);
    Task<IEnumerable<UserActivityLog>> GetUserActivitiesAsync(Guid userId, int pageNumber, int pageSize, CancellationToken cancellationToken = default);
    Task<int> GetUserActivityCountAsync(Guid userId, CancellationToken cancellationToken = default);
}
