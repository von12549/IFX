// User is in same namespace (IFX.Modules.Auth.Domain.Users)

namespace IFX.Modules.Auth.Domain.Users;

public interface IUserRepository
{
    Task<User?> GetByIdAsync(Guid id, CancellationToken cancellationToken = default);
    Task<User?> GetByIssuerAndSubjectAsync(string issuer, string subject, CancellationToken cancellationToken = default);
    Task<User?> GetByEmailAndIdpAsync(string email, Guid idpId, CancellationToken cancellationToken = default);
    Task<(List<User> Users, int TotalCount)> GetAllUsersAsync(int pageNumber, int pageSize, CancellationToken cancellationToken = default);
    Task AddAsync(User user, CancellationToken cancellationToken = default);
    Task UpdateAsync(User user, CancellationToken cancellationToken = default);
    Task<bool> ExistsAsync(string email, CancellationToken cancellationToken = default);
}
