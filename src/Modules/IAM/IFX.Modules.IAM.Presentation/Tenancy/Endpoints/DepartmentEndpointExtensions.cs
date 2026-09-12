using IFX.Modules.IAM.Presentation.Extensions;
using IFX.BuildingBlocks.Application.Context;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.IAM.Presentation.Tenancy.Endpoints;

public static class DepartmentEndpointExtensions
{
    public static IEndpointRouteBuilder MapDepartmentEndpoints(this IEndpointRouteBuilder builder)
    {
        var group = builder.MapGroup("/api/v1/department")
            .WithTags("Department")
            .WithMetadata(ExecutionScopeRequirement.Tenant)
            .RequireAuthorization();

        group.MapGet("/",
            (IServiceProvider services) =>
                DepartmentEndpoints.GetAllDepartments(
                    services.GetRequiredService<MediatR.IMediator>(),
                    services.GetRequiredService<ILogger<DepartmentEndpointsLogCategory>>()))
            .WithName("GetAllDepartments")
            .RequirePermission("Department:list")
            .WithSummary("Get all departments for the current tenant (from X-Tenant-Id header)")
            .Produces<object>(StatusCodes.Status200OK)
            .Produces<object>(StatusCodes.Status401Unauthorized);

        group.MapGet("/{departmentId}", DepartmentEndpoints.GetDepartmentById)
            .WithName("GetDepartmentById")
            .RequirePermission("Department:read")
            .WithSummary("Get a department by ID")
            .Produces<object>(StatusCodes.Status200OK)
            .Produces<object>(StatusCodes.Status401Unauthorized)
            .Produces<object>(StatusCodes.Status404NotFound);

        group.MapPost("/", DepartmentEndpoints.CreateDepartment)
            .WithName("CreateDepartment")
            .RequirePermission("Department:create")
            .WithSummary("Create a new department")
            .Produces<object>(StatusCodes.Status200OK)
            .Produces<object>(StatusCodes.Status400BadRequest)
            .Produces<object>(StatusCodes.Status401Unauthorized);

        group.MapPut("/{departmentId}", DepartmentEndpoints.UpdateDepartment)
            .WithName("UpdateDepartment")
            .RequirePermission("Department:update")
            .WithSummary("Update an existing department")
            .Produces<object>(StatusCodes.Status200OK)
            .Produces<object>(StatusCodes.Status400BadRequest)
            .Produces<object>(StatusCodes.Status401Unauthorized);

        group.MapDelete("/{departmentId}", DepartmentEndpoints.DeleteDepartment)
            .WithName("DeleteDepartment")
            .RequirePermission("Department:delete")
            .WithSummary("Delete a department")
            .Produces<object>(StatusCodes.Status200OK)
            .Produces<object>(StatusCodes.Status400BadRequest)
            .Produces<object>(StatusCodes.Status401Unauthorized);

        return builder;
    }

}
