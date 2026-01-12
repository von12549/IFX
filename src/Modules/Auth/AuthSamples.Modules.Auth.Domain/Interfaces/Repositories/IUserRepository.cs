using AuthSamples.Modules.Auth.Domain.Entities;

namespace AuthSamples.Modules.Auth.Domain.Interfaces.Repositories;

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
