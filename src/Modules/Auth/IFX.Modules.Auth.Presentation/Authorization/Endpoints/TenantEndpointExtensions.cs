using IFX.Modules.Auth.Presentation.Extensions;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;

namespace IFX.Modules.Auth.Presentation.Authorization.Endpoints;

public static class TenantEndpointExtensions
{
    public static IEndpointRouteBuilder MapTenantEndpoints(this IEndpointRouteBuilder builder)
    {
        var group = builder.MapGroup("/api/v1/tenant")
            .WithTags("Tenant")
            .RequireAuthorization();

        group.MapGet("/", TenantEndpoints.GetAllTenants)
            .WithName("GetAllTenants")
            .RequirePermission("Tenant.Read")
            .WithSummary("Get all tenants")
            .Produces<object>(StatusCodes.Status200OK)
            .Produces<object>(StatusCodes.Status401Unauthorized);

        group.MapGet("/{tenantId}", TenantEndpoints.GetTenantById)
            .WithName("GetTenantById")
            .RequirePermission("Tenant.Read")
            .WithSummary("Get a tenant by ID")
            .Produces<object>(StatusCodes.Status200OK)
            .Produces<object>(StatusCodes.Status401Unauthorized)
            .Produces<object>(StatusCodes.Status404NotFound);

        group.MapPost("/", TenantEndpoints.CreateTenant)
            .WithName("CreateTenant")
            .RequirePermission("Tenant.Write")
            .WithSummary("Create a new tenant")
            .Produces<object>(StatusCodes.Status200OK)
            .Produces<object>(StatusCodes.Status400BadRequest)
            .Produces<object>(StatusCodes.Status401Unauthorized);

        group.MapPut("/{tenantId}", TenantEndpoints.UpdateTenant)
            .WithName("UpdateTenant")
            .RequirePermission("Tenant.Write")
            .WithSummary("Update an existing tenant")
            .Produces<object>(StatusCodes.Status200OK)
            .Produces<object>(StatusCodes.Status400BadRequest)
            .Produces<object>(StatusCodes.Status401Unauthorized);

        group.MapDelete("/{tenantId}", TenantEndpoints.DeleteTenant)
            .WithName("DeleteTenant")
            .RequirePermission("Tenant.Write")
            .WithSummary("Delete a tenant")
            .Produces<object>(StatusCodes.Status200OK)
            .Produces<object>(StatusCodes.Status400BadRequest)
            .Produces<object>(StatusCodes.Status401Unauthorized);

        return builder;
    }
}
