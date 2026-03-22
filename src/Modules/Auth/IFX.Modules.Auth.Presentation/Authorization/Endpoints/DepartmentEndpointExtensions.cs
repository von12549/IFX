using IFX.Modules.Auth.Presentation.Extensions;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.Auth.Presentation.Authorization.Endpoints;

public static class DepartmentEndpointExtensions
{
    public static IEndpointRouteBuilder MapDepartmentEndpoints(this IEndpointRouteBuilder builder)
    {
        var group = builder.MapGroup("/api/v1/department")
            .WithTags("Department")
            .RequireAuthorization();

        group.MapGet("/",
            ([AsParameters] DepartmentParams parameters, IServiceProvider services) =>
                DepartmentEndpoints.GetAllDepartments(
                    parameters.tenantId,
                    services.GetRequiredService<MediatR.IMediator>(),
                    services.GetRequiredService<ILogger<DepartmentEndpointsLogCategory>>()))
            .WithName("GetAllDepartments")
            .RequirePermission("Department.Read")
            .WithSummary("Get all departments, optionally filtered by tenantId")
            .Produces<object>(StatusCodes.Status200OK)
            .Produces<object>(StatusCodes.Status401Unauthorized);

        group.MapGet("/{departmentId}", DepartmentEndpoints.GetDepartmentById)
            .WithName("GetDepartmentById")
            .RequirePermission("Department.Read")
            .WithSummary("Get a department by ID")
            .Produces<object>(StatusCodes.Status200OK)
            .Produces<object>(StatusCodes.Status401Unauthorized)
            .Produces<object>(StatusCodes.Status404NotFound);

        group.MapPost("/", DepartmentEndpoints.CreateDepartment)
            .WithName("CreateDepartment")
            .RequirePermission("Department.Write")
            .WithSummary("Create a new department")
            .Produces<object>(StatusCodes.Status200OK)
            .Produces<object>(StatusCodes.Status400BadRequest)
            .Produces<object>(StatusCodes.Status401Unauthorized);

        group.MapPut("/{departmentId}", DepartmentEndpoints.UpdateDepartment)
            .WithName("UpdateDepartment")
            .RequirePermission("Department.Write")
            .WithSummary("Update an existing department")
            .Produces<object>(StatusCodes.Status200OK)
            .Produces<object>(StatusCodes.Status400BadRequest)
            .Produces<object>(StatusCodes.Status401Unauthorized);

        group.MapDelete("/{departmentId}", DepartmentEndpoints.DeleteDepartment)
            .WithName("DeleteDepartment")
            .RequirePermission("Department.Write")
            .WithSummary("Delete a department")
            .Produces<object>(StatusCodes.Status200OK)
            .Produces<object>(StatusCodes.Status400BadRequest)
            .Produces<object>(StatusCodes.Status401Unauthorized);

        return builder;
    }

    private record DepartmentParams(Guid? tenantId = null);
}
