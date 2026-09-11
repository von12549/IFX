using IFX.BuildingBlocks.Security.Authorization;

namespace IFX.Modules.Auth.Infrastructure.Authorization;

/// <summary>
/// Checks coarse-grained RBAC permissions from the current user's permission claims.
/// Permission claims are pre-loaded per-request by UserPermissionClaimsTransformation.
/// </summary>
public class PermissionChecker : IPermissionChecker
{
    private readonly ICurrentUser _currentUser;

    public PermissionChecker(ICurrentUser currentUser)
    {
        _currentUser = currentUser;
    }

    public Task<bool> HasPermissionAsync(string permission, CancellationToken ct = default)
    {
        var result = _currentUser.IsAuthenticated &&
                     (_currentUser.GlobalRoles.Count > 0 ||
                      _currentUser.Permissions.Contains(permission, StringComparer.OrdinalIgnoreCase));
        return Task.FromResult(result);
    }
}
