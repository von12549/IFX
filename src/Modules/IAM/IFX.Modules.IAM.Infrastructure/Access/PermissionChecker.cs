using IFX.BuildingBlocks.Security.Authorization;
using IFX.BuildingBlocks.Application.Context;
using IFX.Modules.IAM.Application.Access;
using IFX.Platform.Context.Contracts;
using IFX.Platform.Context.Contracts.Context;

namespace IFX.Modules.IAM.Infrastructure.Access;

/// <summary>
/// Checks current IAM facts in the trusted execution scope, including background callers.
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
            _execution.Current.Provenance != ContextProvenance.Trusted || _execution.Current.Actor.Kind != ActorKind.User || !Guid.TryParse(_execution.Current.Actor.Id, out var actorId) || actorId != _currentUser.UserId)
            return Task.FromResult(false);
        var parts = permission.Split(':');
        var resource = parts[0].Equals("Platform.Policy", StringComparison.OrdinalIgnoreCase) ? "platform_policy" : parts[0].ToLowerInvariant();
        var result = _execution.Current.IsTenantScope
            ? _currentUser.TenantId == _execution.Current.TenantId && _currentUser.TenantId is not null &&
              _currentUser.Permissions.Contains(permission, StringComparer.OrdinalIgnoreCase)
            : permission.Equals("Platform.GlobalRole:manage", StringComparison.OrdinalIgnoreCase)
                ? _currentUser.IsGlobalAdmin
                : parts.Length == 2 && _currentUser.GlobalRoles.Any(role => AccessPolicySemantics.GlobalRoleGrants(role, resource, parts[1]));
        return Task.FromResult(result);
    }
}
