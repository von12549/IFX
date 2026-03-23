using IFX.BuildingBlocks.Security.Authorization.Abstractions;
using IFX.BuildingBlocks.Security.Authorization.Exceptions;
using IFX.BuildingBlocks.Security.Authorization.Models;
using Microsoft.AspNetCore.Http;
using Microsoft.Extensions.Logging;

namespace IFX.BuildingBlocks.Security.Authorization;

public class ResourceAuthorizationService : IResourceAuthorizationService
{
    private readonly ICurrentUser _currentUser;
    private readonly IPermissionChecker _permissionChecker;
    private readonly IOpaPolicyClient _opaClient;
    private readonly IHttpContextAccessor _httpContextAccessor;
    private readonly ILogger<ResourceAuthorizationService> _logger;

    public ResourceAuthorizationService(
        ICurrentUser currentUser,
        IPermissionChecker permissionChecker,
        IOpaPolicyClient opaClient,
        IHttpContextAccessor httpContextAccessor,
        ILogger<ResourceAuthorizationService> logger)
    {
        _currentUser = currentUser;
        _permissionChecker = permissionChecker;
        _opaClient = opaClient;
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
                Mfa = _currentUser.MfaEnabled
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
