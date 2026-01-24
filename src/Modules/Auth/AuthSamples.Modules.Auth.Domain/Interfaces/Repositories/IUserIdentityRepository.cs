using AuthSamples.Modules.Auth.Domain.Entities;

namespace AuthSamples.Modules.Auth.Domain.Interfaces.Repositories;

public interface IUserIdentityRepository
{
    Task<UserIdentity?> GetByIdAsync(Guid id, CancellationToken cancellationToken = default);
    Task<UserIdentity?> GetByIssuerAndSubjectAsync(string issuer, string subject, CancellationToken cancellationToken = default);
    Task<UserIdentity?> GetByEmailAsync(string email, CancellationToken cancellationToken = default);
    Task<List<UserIdentity>> GetByUserIdAsync(Guid userId, CancellationToken cancellationToken = default);
    Task AddAsync(UserIdentity userIdentity, CancellationToken cancellationToken = default);
    Task UpdateAsync(UserIdentity userIdentity, CancellationToken cancellationToken = default);
}
