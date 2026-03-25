using IFX.BuildingBlocks.Security.Authorization.Abac.Engine;
using IFX.BuildingBlocks.Security.Authorization.Abac.Policies;
using IFX.BuildingBlocks.Security.Authorization.Abac.Resolver;
using IFX.BuildingBlocks.Security.Authorization.Abstractions;
using IFX.BuildingBlocks.Security.Authorization.Exceptions;
using IFX.BuildingBlocks.Security.Authorization.Models;
using Microsoft.AspNetCore.Http;
using Microsoft.Extensions.Logging;

namespace IFX.BuildingBlocks.Security.Authorization;

public class ResourceAuthorizationService : IResourceAuthorizationService
{
    private const string AbacEvalPath = "authz/common/abac_eval";

    private readonly ICurrentUser _currentUser;
    private readonly IPermissionChecker _permissionChecker;
    private readonly IOpaPolicyClient _opaClient;
    private readonly IAbacPolicyEngine _abacEngine;
    private readonly IAbacPolicyResolver _policyResolver;
    private readonly IHttpContextAccessor _httpContextAccessor;
    private readonly ILogger<ResourceAuthorizationService> _logger;

    public ResourceAuthorizationService(
        ICurrentUser currentUser,
        IPermissionChecker permissionChecker,
        IOpaPolicyClient opaClient,
        IAbacPolicyEngine abacEngine,
        IAbacPolicyResolver policyResolver,
        IHttpContextAccessor httpContextAccessor,
        ILogger<ResourceAuthorizationService> logger)
    {
        _currentUser = currentUser;
        _permissionChecker = permissionChecker;
        _opaClient = opaClient;
        _abacEngine = abacEngine;
        _policyResolver = policyResolver;
        _httpContextAccessor = httpContextAccessor;
        _logger = logger;
    }

    public async Task AuthorizeAsync<TResource>(
        string? requiredPermission,
        string decisionPath,
        TResource resourceAttributes,
        string action,
        CancellationToken ct = default)
        where TResource : OpaResourceAttributesBase
    {
        // Step 1: Coarse-grained RBAC check (skipped when requiredPermission is null)
        if (requiredPermission is not null &&
            !await _permissionChecker.HasPermissionAsync(requiredPermission, ct))
        {
            _logger.LogWarning(
                "RBAC denied: user {UserId} lacks permission '{Permission}' for action '{Action}' on {ResourceType}/{ResourceId}",
                _currentUser.UserId, requiredPermission, action, resourceAttributes.Type, resourceAttributes.Id);
            throw new ForbiddenException($"Permission '{requiredPermission}' is required.");
        }

        // Step 2: Build OPA envelope
        var httpContext = _httpContextAccessor.HttpContext;
        var envelope = new OpaAuthorizationEnvelope<TResource>
        {
            Subject = new OpaSubjectAttributes
            {
                Id = _currentUser.UserId.ToString(),
                TenantId = _currentUser.TenantId?.ToString(),
                Departments = _currentUser.Departments,
                Roles = _currentUser.Roles,
                Permissions = _currentUser.Permissions,
                Mfa = _currentUser.MfaEnabled,
                GlobalRoles = _currentUser.GlobalRoles,
                IsGlobalAdmin = _currentUser.IsGlobalAdmin ? "true" : "false"
            },
            Resource = resourceAttributes,
            Action = action,
            Environment = new OpaEnvironmentAttributes
            {
                Ip = httpContext?.Connection.RemoteIpAddress?.ToString(),
                Network = ResolveNetwork(httpContext),
                Time = DateTime.UtcNow.ToString("O")
            }
        };

        // Step 3: OPA policy evaluation
        var decision = await _opaClient.EvaluateAsync(decisionPath, envelope, ct);

        if (!decision.Allow)
        {
            _logger.LogWarning(
                "OPA denied: user {UserId} action '{Action}' on {ResourceType}/{ResourceId} via policy '{Path}'. Reason: {Reason}",
                _currentUser.UserId, action, resourceAttributes.Type, resourceAttributes.Id,
                decisionPath, decision.DenyReason ?? "policy returned false");
            throw new ForbiddenException("Access denied by policy.");
        }

        _logger.LogDebug(
            "Authorized: user {UserId} action '{Action}' on {ResourceType}/{ResourceId}",
            _currentUser.UserId, action, resourceAttributes.Type, resourceAttributes.Id);
    }

    public async Task AuthorizeWithPolicyAsync<TResource>(
        AbacPolicy policy,
        TResource resourceAttributes,
        IDictionary<string, object>? parameters = null,
        CancellationToken ct = default)
        where TResource : OpaResourceAttributesBase
    {
        // Resolve conditions (throws ArgumentException on missing UserInput params)
        var conditions = _abacEngine.Resolve(policy, parameters);

        // Build OPA envelope with resolved conditions
        var httpContext = _httpContextAccessor.HttpContext;
        var envelope = new OpaAuthorizationEnvelope<TResource>
        {
            Subject = new OpaSubjectAttributes
            {
                Id = _currentUser.UserId.ToString(),
                TenantId = _currentUser.TenantId?.ToString(),
                Departments = _currentUser.Departments,
                Roles = _currentUser.Roles,
                Permissions = _currentUser.Permissions,
                Mfa = _currentUser.MfaEnabled,
                GlobalRoles = _currentUser.GlobalRoles,
                IsGlobalAdmin = _currentUser.IsGlobalAdmin ? "true" : "false"
            },
            Resource = resourceAttributes,
            Action = policy.Action,
            Environment = new OpaEnvironmentAttributes
            {
                Ip = httpContext?.Connection.RemoteIpAddress?.ToString(),
                Network = ResolveNetwork(httpContext),
                Time = DateTime.UtcNow.ToString("O")
            },
            Conditions = conditions
        };

        // Evaluate against the generic ABAC evaluator policy
        var decision = await _opaClient.EvaluateAsync(AbacEvalPath, envelope, ct);

        if (!decision.Allow)
        {
            _logger.LogWarning(
                "ABAC denied: user {UserId} action '{Action}' on {ResourceType}/{ResourceId} " +
                "via policy '{Path}' ({ConditionCount} conditions). Reason: {Reason}",
                _currentUser.UserId, policy.Action, resourceAttributes.Type, resourceAttributes.Id,
                AbacEvalPath, conditions.Count, decision.DenyReason ?? "policy returned false");
            throw new ForbiddenException("Access denied by policy.");
        }

        _logger.LogDebug(
            "ABAC authorized: user {UserId} action '{Action}' on {ResourceType}/{ResourceId} ({ConditionCount} conditions)",
            _currentUser.UserId, policy.Action, resourceAttributes.Type, resourceAttributes.Id, conditions.Count);
    }

    public async Task AuthorizeWithResolvedPolicyAsync<TResource>(
        string resourceType,
        string action,
        TResource resourceAttributes,
        IDictionary<string, object>? parameters = null,
        CancellationToken ct = default)
        where TResource : OpaResourceAttributesBase
    {
        AbacPolicy? policy;
        if (_currentUser.GlobalRoles.Count > 0)
            policy = await _policyResolver.ResolvePlatformPolicyAsync(resourceType, action, ct);
        else if (_currentUser.TenantId.HasValue)
            policy = await _policyResolver.ResolveTenantPolicyAsync(_currentUser.TenantId.Value, resourceType, action, ct);
        else
            policy = null;

        if (policy is null)
        {
            _logger.LogWarning(
                "ABAC denied (no policy): user {UserId} action '{Action}' on {ResourceType}",
                _currentUser.UserId, action, resourceType);
            throw new ForbiddenException($"No ABAC policy defined for '{resourceType}/{action}'.");
        }

        await AuthorizeWithPolicyAsync(policy, resourceAttributes, parameters, ct);
    }

    private static string? ResolveNetwork(HttpContext? ctx)
    {
        if (ctx is null) return null;
        var ip = ctx.Connection.RemoteIpAddress;
        if (ip is null) return null;
        // Treat loopback and private ranges as internal
        return System.Net.IPAddress.IsLoopback(ip) || IsPrivate(ip) ? "internal" : "external";
    }

    private static bool IsPrivate(System.Net.IPAddress ip)
    {
        var bytes = ip.GetAddressBytes();
        return bytes.Length == 4 && (
            bytes[0] == 10 ||
            (bytes[0] == 172 && bytes[1] >= 16 && bytes[1] <= 31) ||
            (bytes[0] == 192 && bytes[1] == 168));
    }
}
