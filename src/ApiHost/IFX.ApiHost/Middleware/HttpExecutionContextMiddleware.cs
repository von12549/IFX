using IFX.BuildingBlocks.Application.Context;
using IFX.BuildingBlocks.Security.Authorization.Abstractions;

namespace IFX.ApiHost.Middleware;

public sealed class HttpExecutionContextMiddleware(RequestDelegate next)
{
    internal const string OperationItemKey = "IFX.OperationId";

    public async Task InvokeAsync(
        HttpContext context,
        IExecutionContextScopeFactory scopeFactory,
        IExecutionIdentityFacts identityFacts,
        ICurrentUser currentUser)
    {
        var requirement = context.GetEndpoint()?.Metadata.GetMetadata<ExecutionScopeRequirement>();
        if (requirement is null)
        {
            if (context.Request.Path.StartsWithSegments("/api/v1") ||
                context.Request.Path.StartsWithSegments("/management"))
            {
                await HttpBoundaryResponse.WriteAsync(
                    context,
                    StatusCodes.Status500InternalServerError,
                    "execution_scope_undefined",
                    "The endpoint execution scope is not configured.");
                return;
            }

            requirement = ExecutionScopeRequirement.Public;
        }

        if (!requirement.AllowAnonymous && !identityFacts.IsAuthenticated)
        {
            await HttpBoundaryResponse.WriteAsync(
                context,
                StatusCodes.Status401Unauthorized,
                "authentication_required",
                "Authentication is required.");
            return;
        }

        var actor = CreateActor(identityFacts, requirement.AllowAnonymous);
        if (actor is null)
        {
            await HttpBoundaryResponse.WriteAsync(
                context,
                StatusCodes.Status401Unauthorized,
                "actor_context_invalid",
                "The authenticated actor context is invalid.");
            return;
        }

        var tenantId = requirement.Kind switch
        {
            ExecutionScopeRequirementKind.Platform => await ResolvePlatformScopeAsync(
                context,
                requirement,
                currentUser),
            ExecutionScopeRequirementKind.Tenant => await ResolveTenantScopeAsync(
                context,
                requirement,
                identityFacts,
                currentUser),
            _ => null
        };

        if (tenantId is null)
        {
            return;
        }

        var operationId = Guid.NewGuid();
        var snapshot = requirement.Kind == ExecutionScopeRequirementKind.Tenant
            ? ExecutionContextSnapshot.ForTenant(
                HttpCorrelationMiddleware.GetCorrelation(context),
                operationId,
                causationId: null,
                tenantId!.Value,
                actor.Value.Kind,
                actor.Value.Id,
                "ifx",
                "api-host",
                1)
            : ExecutionContextSnapshot.ForPlatform(
                HttpCorrelationMiddleware.GetCorrelation(context),
                operationId,
                causationId: null,
                actor.Value.Kind,
                actor.Value.Id,
                "ifx",
                "api-host",
                1);
        context.Items[OperationItemKey] = operationId.ToString("D");

        await scopeFactory.RunAsync(snapshot, _ => next(context), context.RequestAborted);
    }

    private static (string Kind, string Id)? CreateActor(IExecutionIdentityFacts identityFacts, bool allowAnonymous)
    {
        if (!identityFacts.IsAuthenticated)
        {
            return allowAnonymous ? ("system", "anonymous") : null;
        }

        return identityFacts.UserId == Guid.Empty
            ? null
            : ("user", identityFacts.UserId.ToString("D"));
    }

    private static async Task<Guid?> ResolvePlatformScopeAsync(
        HttpContext context,
        ExecutionScopeRequirement requirement,
        ICurrentUser currentUser)
    {
        if (!requirement.AllowAnonymous && !currentUser.IsGlobalAdmin)
        {
            await HttpBoundaryResponse.WriteAsync(
                context,
                StatusCodes.Status403Forbidden,
                "platform_access_denied",
                "Platform access is denied.");
            return null;
        }

        return Guid.Empty;
    }

    private static async Task<Guid?> ResolveTenantScopeAsync(
        HttpContext context,
        ExecutionScopeRequirement requirement,
        IExecutionIdentityFacts identityFacts,
        ICurrentUser currentUser)
    {
        var headerPresent = context.Request.Headers.ContainsKey("X-Tenant-Id");
        var values = context.Request.Headers.GetCommaSeparatedValues("X-Tenant-Id");
        Guid tenantId;

        if (headerPresent)
        {
            if (values.Length != 1 || !Guid.TryParseExact(values[0], "D", out tenantId) || tenantId == Guid.Empty)
            {
                await HttpBoundaryResponse.WriteAsync(
                    context,
                    StatusCodes.Status400BadRequest,
                    "tenant_context_invalid",
                    "The tenant context is invalid.");
                return null;
            }

            if (!currentUser.IsGlobalAdmin && !identityFacts.IsTenantMember(tenantId))
            {
                await HttpBoundaryResponse.WriteAsync(
                    context,
                    StatusCodes.Status403Forbidden,
                    "tenant_access_denied",
                    "Access to the selected tenant is denied.");
                return null;
            }
        }
        else
        {
            if (!requirement.AllowPrimaryTenantFallback || currentUser.IsGlobalAdmin)
            {
                await HttpBoundaryResponse.WriteAsync(
                    context,
                    StatusCodes.Status400BadRequest,
                    "tenant_context_required",
                    "An explicit tenant context is required.");
                return null;
            }

            if (identityFacts.PrimaryTenantId is not { } primaryTenantId)
            {
                await HttpBoundaryResponse.WriteAsync(
                    context,
                    StatusCodes.Status400BadRequest,
                    "tenant_context_required",
                    "A tenant context is required.");
                return null;
            }

            if (!identityFacts.IsTenantMember(primaryTenantId))
            {
                await HttpBoundaryResponse.WriteAsync(
                    context,
                    StatusCodes.Status403Forbidden,
                    "tenant_access_denied",
                    "Access to the selected tenant is denied.");
                return null;
            }

            tenantId = primaryTenantId;
        }

        return tenantId;
    }
}

internal static class HttpBoundaryResponse
{
    public static Task WriteAsync(HttpContext context, int statusCode, string errorCode, string safeMessage)
    {
        context.Response.StatusCode = statusCode;
        context.Response.ContentType = "application/json";
        return context.Response.WriteAsJsonAsync(new ErrorResponse
        {
            Success = false,
            ErrorCode = errorCode,
            Error = safeMessage,
            CorrelationId = HttpCorrelationMiddleware.GetCorrelation(context).ToString("D"),
            Timestamp = DateTimeOffset.UtcNow
        });
    }
}
