// UserRole is in same namespace (IFX.Modules.Auth.Domain.Authorization)

namespace IFX.Modules.Auth.Domain.Authorization;

public interface IUserRoleRepository
{
    Task<UserRole?> GetByIdAsync(Guid id, CancellationToken cancellationToken = default);
    Task<UserRole?> GetByRoleNameAsync(string roleName, CancellationToken cancellationToken = default);
    Task<List<UserRole>> GetAllAsync(CancellationToken cancellationToken = default);
    Task AddAsync(UserRole role, CancellationToken cancellationToken = default);
    Task<bool> RoleNameExistsAsync(string roleName, CancellationToken cancellationToken = default);
    Task<bool> RoleNameExistsAsync(string roleName, Guid excludeRoleId, CancellationToken cancellationToken = default);
}
