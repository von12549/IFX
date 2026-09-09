// Types are in same namespace (IFX.Modules.Auth.Domain.Identity)

namespace IFX.Modules.Auth.Domain.Identity;

public interface IIdpRepository
{
    Task<Idp?> GetByIdAsync(Guid id, Guid tenantId, CancellationToken cancellationToken = default);
    Task<Idp?> GetByIssuerAsync(string issuer, CancellationToken cancellationToken = default);
    Task<Idp?> GetPrimaryIdpAsync(CancellationToken cancellationToken = default);
    Task<List<Idp>> GetAcrossTenantsAsync(int maxRows, CancellationToken cancellationToken = default);
    Task<List<Idp>> GetByTenantIdAsync(Guid tenantId, CancellationToken cancellationToken = default);
    Task<List<Idp>> GetEnabledAsync(CancellationToken cancellationToken = default);
    Task<Idp?> GetEnabledByIssuerAsync(string issuer, CancellationToken cancellationToken = default);
    Task AddAsync(Idp idp, CancellationToken cancellationToken = default);
    Task<bool> IssuerExistsAsync(string issuer, CancellationToken cancellationToken = default);
    Task<bool> IssuerExistsAsync(string issuer, Guid excludeIdpId, CancellationToken cancellationToken = default);
    Task ClearPrimaryFlagAsync(CancellationToken cancellationToken = default);
}
