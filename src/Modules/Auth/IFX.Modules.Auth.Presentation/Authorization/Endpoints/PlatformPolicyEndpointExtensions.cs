using IFX.Modules.Auth.Presentation.Extensions;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;

namespace IFX.Modules.Auth.Presentation.Authorization.Endpoints;

public static class PlatformPolicyEndpointExtensions
{
    public static IEndpointRouteBuilder MapPlatformPolicyEndpoints(this IEndpointRouteBuilder builder)
    {
        var group = builder.MapGroup("/api/v1/platform/policy")
            .WithTags("Platform Policy")
            .RequireAuthorization();

        group.MapGet("/", PlatformPolicyEndpoints.GetPlatformPolicies)
            .WithName("GetPlatformPolicies")
            .RequirePermission("Platform.Policy.Read")
            .WithSummary("Get all platform-level ABAC policy definitions")
            .Produces<object>(StatusCodes.Status200OK)
            .Produces<object>(StatusCodes.Status401Unauthorized);

        group.MapPost("/", PlatformPolicyEndpoints.CreatePlatformPolicy)
            .WithName("CreatePlatformPolicy")
            .RequirePermission("Platform.Policy.Write")
            .WithSummary("Create a platform-level ABAC policy definition")
            .Produces<object>(StatusCodes.Status200OK)
            .Produces<object>(StatusCodes.Status400BadRequest)
            .Produces<object>(StatusCodes.Status401Unauthorized);

        group.MapPut("/{policyId}", PlatformPolicyEndpoints.UpdatePlatformPolicy)
            .WithName("UpdatePlatformPolicy")
            .RequirePermission("Platform.Policy.Write")
            .WithSummary("Update a platform-level ABAC policy definition")
            .Produces<object>(StatusCodes.Status200OK)
            .Produces<object>(StatusCodes.Status400BadRequest)
            .Produces<object>(StatusCodes.Status401Unauthorized);

        group.MapDelete("/{policyId}", PlatformPolicyEndpoints.DeletePlatformPolicy)
            .WithName("DeletePlatformPolicy")
            .RequirePermission("Platform.Policy.Write")
            .WithSummary("Delete a platform-level ABAC policy definition")
            .Produces<object>(StatusCodes.Status200OK)
            .Produces<object>(StatusCodes.Status400BadRequest)
            .Produces<object>(StatusCodes.Status401Unauthorized);

        return builder;
    }
}
