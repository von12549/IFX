namespace IFX.Modules.Auth.Domain.Authorization;

public interface IGlobalRoleRepository
{
    Task<GlobalRole?> GetByIdAsync(Guid id, CancellationToken ct = default);
    Task<GlobalRole?> GetByNameAsync(string name, CancellationToken ct = default);
    Task<IReadOnlyList<GlobalRole>> GetAllAsync(CancellationToken ct = default);
    Task<IReadOnlyList<GlobalRole>> GetByUserIdAsync(Guid userId, CancellationToken ct = default);
    Task AddAsync(GlobalRole role, CancellationToken ct = default);
    Task<UserGlobalRole?> GetUserGlobalRoleAsync(Guid userId, Guid globalRoleId, CancellationToken ct = default);
    Task AddUserGlobalRoleAsync(UserGlobalRole userGlobalRole, CancellationToken ct = default);
    void RemoveUserGlobalRole(UserGlobalRole userGlobalRole);
    Task<int> CountPlatformAdminsAsync(CancellationToken ct = default);
}
