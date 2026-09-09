namespace IFX.Modules.Auth.Domain.Users;

public interface IUserRepository
{
    Task<User?> GetByIdAsync(Guid id, CancellationToken cancellationToken = default);
    Task<User?> GetByIdWithTenantsAndDepartmentsAsync(Guid id, CancellationToken cancellationToken = default);
    Task<User?> GetByIdWithRolesAndGroupsAsync(Guid id, CancellationToken cancellationToken = default);
    Task<User?> GetByIssuerAndSubjectAsync(string issuer, string subject, CancellationToken cancellationToken = default);
    Task<User?> GetByIssuerAndSubjectWithPermissionsAsync(string issuer, string subject, CancellationToken cancellationToken = default);
    Task<User?> GetByEmailAndIdpAsync(string email, Guid idpId, CancellationToken cancellationToken = default);
    Task<(List<User> Users, int TotalCount)> GetAllUsersAsync(int pageNumber, int pageSize, CancellationToken cancellationToken = default);
    Task<(List<User> Users, int TotalCount)> GetAllUsersByTenantAsync(Guid tenantId, int pageNumber, int pageSize, CancellationToken cancellationToken = default);
    Task<List<User>> GetAcrossTenantsWithTenantsAsync(int maxRows, CancellationToken cancellationToken = default);
    Task AddAsync(User user, CancellationToken cancellationToken = default);
    Task UpdateAsync(User user, CancellationToken cancellationToken = default);
    Task<bool> ExistsAsync(string email, CancellationToken cancellationToken = default);
}
