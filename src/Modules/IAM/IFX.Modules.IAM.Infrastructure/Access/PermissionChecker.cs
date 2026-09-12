using IFX.BuildingBlocks.Security.Authorization;
using IFX.BuildingBlocks.Application.Context;
using IFX.Modules.IAM.Application.Access;
using IFX.Platform.Context.Contracts;

namespace IFX.Modules.IAM.Infrastructure.Access;

/// <summary>
/// Checks coarse-grained RBAC permissions from the current user's permission claims.
/// Permission claims are pre-loaded per-request by UserPermissionClaimsTransformation.
/// </summary>
public class PermissionChecker : IPermissionChecker
{
    private readonly ICurrentUser _currentUser;
    private readonly IExecutionContextAccessor _execution;

    public PermissionChecker(ICurrentUser currentUser, IExecutionContextAccessor execution)
    {
        _currentUser = currentUser;
        _execution = execution;
    }

    public Task<bool> HasPermissionAsync(string permission, CancellationToken ct = default)
    {
        ct.ThrowIfCancellationRequested();
        if (!_execution.HasCurrent || !_currentUser.IsAuthenticated || _currentUser.UserId == Guid.Empty ||
            _execution.Current.Provenance != ContextProvenance.Trusted || _execution.Current.Actor.Id != _currentUser.UserId.ToString())
            return Task.FromResult(false);
        var parts = permission.Split(':');
        var resource = parts[0].Equals("Platform.Policy", StringComparison.OrdinalIgnoreCase) ? "platform_policy" : parts[0].ToLowerInvariant();
        var result = _execution.Current.IsTenantScope
            ? _currentUser.Permissions.Contains(permission, StringComparer.OrdinalIgnoreCase)
            : permission.Equals("Platform.GlobalRole:manage", StringComparison.OrdinalIgnoreCase)
                ? _currentUser.IsGlobalAdmin
                : parts.Length == 2 && _currentUser.GlobalRoles.Any(role => AccessPolicySemantics.GlobalRoleGrants(role, resource, parts[1]));
        return Task.FromResult(result);
    }
}
