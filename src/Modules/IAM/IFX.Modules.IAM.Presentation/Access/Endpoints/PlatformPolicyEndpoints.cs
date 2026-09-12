using IFX.Modules.IAM.Application.Access.Policies.Commands.CreatePolicy;
using IFX.Modules.IAM.Domain.Access;
using IFX.Modules.IAM.Domain.Tenancy;
using IFX.Modules.IAM.Application.Access.Policies.Commands.DeletePolicy;
using IFX.Modules.IAM.Application.Access.Policies.Commands.UpdatePolicy;
using IFX.Modules.IAM.Application.Access.Policies.DTOs;
using IFX.Modules.IAM.Application.Access.Policies.Queries.GetPlatformPolicies;
using IFX.Modules.IAM.Presentation.Access.Requests;
using IFX.Modules.IAM.Presentation.Models.Responses;
using MediatR;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.IAM.Presentation.Access.Endpoints;

public sealed class PlatformPolicyEndpointsLogCategory { }

public static class PlatformPolicyEndpoints
{
    public static async Task<IResult> GetPlatformPolicies(
        [FromServices] IMediator mediator,
        [FromServices] ILogger<PlatformPolicyEndpointsLogCategory> logger)
    {
        logger.LogInformation("Listing platform-level ABAC policies");
        var result = await mediator.Send(new GetPlatformPoliciesQuery());

        if (!result.IsSuccess)
            return Results.BadRequest(ApiResponse<object>.FailureResponse(result.Error!));

        return Results.Ok(ApiResponse<object>.SuccessResponse(result.Value!));
    }

    public static async Task<IResult> CreatePlatformPolicy(
        [FromBody] CreatePolicyRequest request,
        [FromServices] IMediator mediator,
        [FromServices] ILogger<PlatformPolicyEndpointsLogCategory> logger)
    {
        logger.LogInformation(
            "Platform admin creating policy '{Name}' ({ResourceType}/{Action})",
            request.Name, request.ResourceType, request.Action);

        var conditions = request.Conditions
            .Select(c => new PolicyConditionDto(c.TemplateName, c.Parameters))
            .ToList();

        var result = await mediator.Send(
            new CreatePolicyCommand(PolicyScope.Platform, null, request.Name, request.Description, request.ResourceType, request.Action, conditions));

        if (!result.IsSuccess)
            return Results.BadRequest(ApiResponse<object>.FailureResponse(result.Error!));

        return Results.Ok(ApiResponse<object>.SuccessResponse(result.Value!));
    }

    public static async Task<IResult> UpdatePlatformPolicy(
        Guid policyId,
        [FromBody] UpdatePolicyRequest request,
        [FromServices] IMediator mediator,
        [FromServices] ILogger<PlatformPolicyEndpointsLogCategory> logger)
    {
        logger.LogInformation("Platform admin updating policy {PolicyId}", policyId);

        var conditions = request.Conditions
            .Select(c => new PolicyConditionDto(c.TemplateName, c.Parameters))
            .ToList();

        var result = await mediator.Send(new UpdatePolicyCommand(policyId, request.Name, request.Description, conditions));

        if (!result.IsSuccess)
            return Results.BadRequest(ApiResponse<object>.FailureResponse(result.Error!));

        return Results.Ok(ApiResponse<object>.SuccessResponse(result.Value!));
    }

    public static async Task<IResult> DeletePlatformPolicy(
        Guid policyId,
        [FromServices] IMediator mediator,
        [FromServices] ILogger<PlatformPolicyEndpointsLogCategory> logger)
    {
        logger.LogInformation("Platform admin deleting policy {PolicyId}", policyId);

        var result = await mediator.Send(new DeletePolicyCommand(policyId));

        if (!result.IsSuccess)
            return Results.BadRequest(ApiResponse<object>.FailureResponse(result.Error!));

        return Results.Ok(ApiResponse<object>.SuccessResponse(result.Value!));
    }
}
