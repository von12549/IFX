using IFX.Modules.IAM.Presentation.Extensions;
using IFX.BuildingBlocks.Application.Context;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;

namespace IFX.Modules.IAM.Presentation.Access.Endpoints;

public static class PolicyEndpointExtensions
{
    public static IEndpointRouteBuilder MapPolicyEndpoints(this IEndpointRouteBuilder builder)
    {
        var group = builder.MapGroup("/api/v1/policy")
            .WithTags("Policy")
            .WithMetadata(ExecutionScopeRequirement.Tenant)
            .RequireAuthorization();

        group.MapGet("/", PolicyEndpoints.GetPolicies)
            .WithName("GetPolicies")
            .RequirePermission("Policy:list")
            .WithSummary("Get all policies for the selected tenant")
            .Produces<object>(StatusCodes.Status200OK)
            .Produces<object>(StatusCodes.Status401Unauthorized);

        group.MapGet("/templates", PolicyEndpoints.GetAvailableTemplates)
            .WithName("GetAvailableTemplates")
            .RequirePermission("Policy:list")
            .WithSummary("Get all registered condition templates")
            .Produces<object>(StatusCodes.Status200OK)
            .Produces<object>(StatusCodes.Status401Unauthorized);

        group.MapPost("/", PolicyEndpoints.CreatePolicy)
            .WithName("CreatePolicy")
            .RequirePermission("Policy:create")
            .WithSummary("Create a tenant policy override")
            .Produces<object>(StatusCodes.Status200OK)
            .Produces<object>(StatusCodes.Status400BadRequest)
            .Produces<object>(StatusCodes.Status401Unauthorized);

        group.MapPut("/{policyId}", PolicyEndpoints.UpdatePolicy)
            .WithName("UpdatePolicy")
            .RequirePermission("Policy:update")
            .WithSummary("Update a tenant policy override")
            .Produces<object>(StatusCodes.Status200OK)
            .Produces<object>(StatusCodes.Status400BadRequest)
            .Produces<object>(StatusCodes.Status401Unauthorized);

        group.MapDelete("/{policyId}", PolicyEndpoints.DeletePolicy)
            .WithName("DeletePolicy")
            .RequirePermission("Policy:delete")
            .WithSummary("Delete a tenant policy override (reverts to platform default)")
            .Produces<object>(StatusCodes.Status200OK)
            .Produces<object>(StatusCodes.Status400BadRequest)
            .Produces<object>(StatusCodes.Status401Unauthorized);

        return builder;
    }
}
