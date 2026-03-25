using IFX.Modules.Auth.Application.Authorization.Departments.Commands.CreateDepartment;
using IFX.Modules.Auth.Application.Authorization.Departments.Commands.DeleteDepartment;
using IFX.Modules.Auth.Application.Authorization.Departments.Commands.UpdateDepartment;
using IFX.Modules.Auth.Application.Authorization.Departments.Queries.GetAllDepartments;
using IFX.Modules.Auth.Application.Authorization.Departments.Queries.GetDepartmentById;
using IFX.Modules.Auth.Presentation.Authorization.Requests;
using IFX.Modules.Auth.Presentation.Models.Responses;
using MediatR;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.Auth.Presentation.Authorization.Endpoints;

public sealed class DepartmentEndpointsLogCategory { }

public static class DepartmentEndpoints
{
    public static async Task<IResult> GetAllDepartments(
        [FromServices] IMediator mediator,
        [FromServices] ILogger<DepartmentEndpointsLogCategory> logger)
    {
        logger.LogInformation("Accessing departments list");

        var result = await mediator.Send(new GetAllDepartmentsQuery());

        if (!result.IsSuccess)
            return Results.BadRequest(ApiResponse<object>.FailureResponse(result.Error!));

        return Results.Ok(ApiResponse<object>.SuccessResponse(result.Value!));
    }

    public static async Task<IResult> GetDepartmentById(
        Guid departmentId,
        [FromServices] IMediator mediator,
        [FromServices] ILogger<DepartmentEndpointsLogCategory> logger)
    {
        logger.LogInformation("Getting department: {DepartmentId}", departmentId);

        var result = await mediator.Send(new GetDepartmentByIdQuery(departmentId));

        if (!result.IsSuccess)
            return Results.NotFound(ApiResponse<object>.FailureResponse(result.Error!));

        return Results.Ok(ApiResponse<object>.SuccessResponse(result.Value!));
    }

    public static async Task<IResult> CreateDepartment(
        [FromBody] CreateDepartmentRequest request,
        [FromServices] IMediator mediator,
        [FromServices] ILogger<DepartmentEndpointsLogCategory> logger)
    {
        logger.LogInformation("Creating department: {Name}", request.Name);

        var result = await mediator.Send(new CreateDepartmentCommand(request.Name, request.Description, request.TenantId));

        if (!result.IsSuccess)
            return Results.BadRequest(ApiResponse<object>.FailureResponse(result.Error!));

        return Results.Ok(ApiResponse<object>.SuccessResponse(result.Value!));
    }

    public static async Task<IResult> UpdateDepartment(
        Guid departmentId,
        [FromBody] UpdateDepartmentRequest request,
        [FromServices] IMediator mediator,
        [FromServices] ILogger<DepartmentEndpointsLogCategory> logger)
    {
        logger.LogInformation("Updating department: {DepartmentId}", departmentId);

        var result = await mediator.Send(new UpdateDepartmentCommand(departmentId, request.Name, request.Description));

        if (!result.IsSuccess)
            return Results.BadRequest(ApiResponse<object>.FailureResponse(result.Error!));

        return Results.Ok(ApiResponse<object>.SuccessResponse(result.Value!));
    }

    public static async Task<IResult> DeleteDepartment(
        Guid departmentId,
        [FromServices] IMediator mediator,
        [FromServices] ILogger<DepartmentEndpointsLogCategory> logger)
    {
        logger.LogInformation("Deleting department: {DepartmentId}", departmentId);

        var result = await mediator.Send(new DeleteDepartmentCommand(departmentId));

        if (!result.IsSuccess)
            return Results.BadRequest(ApiResponse<object>.FailureResponse(result.Error!));

        return Results.Ok(ApiResponse<object>.SuccessResponse(result.Value!));
    }
}
