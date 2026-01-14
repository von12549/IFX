using AuthSamples.Modules.Auth.Domain.Entities;

namespace AuthSamples.Modules.Auth.Domain.Interfaces.Repositories;

public interface IIdpRepository
{
    Task<Idp?> GetByIdAsync(Guid id, CancellationToken cancellationToken = default);
    Task<Idp?> GetByIssuerAsync(string issuer, CancellationToken cancellationToken = default);
    Task<List<Idp>> GetAllAsync(CancellationToken cancellationToken = default);
    Task<List<Idp>> GetEnabledAsync(CancellationToken cancellationToken = default);
    Task<Idp?> GetEnabledByIssuerAsync(string issuer, CancellationToken cancellationToken = default);
    Task AddAsync(Idp idp, CancellationToken cancellationToken = default);
    Task<bool> IssuerExistsAsync(string issuer, CancellationToken cancellationToken = default);
    Task<bool> IssuerExistsAsync(string issuer, Guid excludeIdpId, CancellationToken cancellationToken = default);
}
