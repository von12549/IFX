using IFX.Modules.Auth.Presentation.Extensions;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;

namespace IFX.Modules.Auth.Presentation.Authorization.Endpoints;

public static class PolicyEndpointExtensions
{
    public static IEndpointRouteBuilder MapPolicyEndpoints(this IEndpointRouteBuilder builder)
    {
        var group = builder.MapGroup("/api/v1/policy")
            .WithTags("Policy")
            .RequireAuthorization();

        group.MapGet("/", PolicyEndpoints.GetPolicies)
            .WithName("GetPolicies")
            .RequirePermission("Policy.Read")
            .WithSummary("Get all policies for the selected tenant")
            .Produces<object>(StatusCodes.Status200OK)
            .Produces<object>(StatusCodes.Status401Unauthorized);

        group.MapGet("/templates", PolicyEndpoints.GetAvailableTemplates)
            .WithName("GetAvailableTemplates")
            .RequirePermission("Policy.Read")
            .WithSummary("Get all registered condition templates")
            .Produces<object>(StatusCodes.Status200OK)
            .Produces<object>(StatusCodes.Status401Unauthorized);

        group.MapPost("/", PolicyEndpoints.CreatePolicy)
            .WithName("CreatePolicy")
            .RequirePermission("Policy.Write")
            .WithSummary("Create a tenant policy override")
            .Produces<object>(StatusCodes.Status200OK)
            .Produces<object>(StatusCodes.Status400BadRequest)
            .Produces<object>(StatusCodes.Status401Unauthorized);

        group.MapPut("/{policyId}", PolicyEndpoints.UpdatePolicy)
            .WithName("UpdatePolicy")
            .RequirePermission("Policy.Write")
            .WithSummary("Update a tenant policy override")
            .Produces<object>(StatusCodes.Status200OK)
            .Produces<object>(StatusCodes.Status400BadRequest)
            .Produces<object>(StatusCodes.Status401Unauthorized);

        group.MapDelete("/{policyId}", PolicyEndpoints.DeletePolicy)
            .WithName("DeletePolicy")
            .RequirePermission("Policy.Write")
            .WithSummary("Delete a tenant policy override (reverts to platform default)")
            .Produces<object>(StatusCodes.Status200OK)
            .Produces<object>(StatusCodes.Status400BadRequest)
            .Produces<object>(StatusCodes.Status401Unauthorized);

        return builder;
    }
}
