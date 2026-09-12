using IFX.BuildingBlocks.Security.Authorization;
using IFX.Modules.IAM.Application.Access.Policies.Commands.CreatePolicy;
using IFX.Modules.IAM.Domain.Access;
using IFX.Modules.IAM.Domain.Tenancy;
using IFX.Modules.IAM.Application.Access.Policies.Commands.DeletePolicy;
using IFX.Modules.IAM.Application.Access.Policies.Commands.UpdatePolicy;
using IFX.Modules.IAM.Application.Access.Policies.DTOs;
using IFX.Modules.IAM.Application.Access.Policies.Queries.GetAvailableTemplates;
using IFX.Modules.IAM.Application.Access.Policies.Queries.GetPolicies;
using IFX.Modules.IAM.Presentation.Access.Requests;
using IFX.Modules.IAM.Presentation.Models.Responses;
using MediatR;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.IAM.Presentation.Access.Endpoints;

public sealed class PolicyEndpointsLogCategory { }

public static class PolicyEndpoints
{
    public static async Task<IResult> GetPolicies(
        [FromServices] IMediator mediator,
        [FromServices] ICurrentUser currentUser,
        [FromServices] ILogger<PolicyEndpointsLogCategory> logger)
    {
        var tenantId = currentUser.TenantId;
        if (tenantId is null)
            return Results.BadRequest(ApiResponse<object>.FailureResponse("No tenant selected."));

        logger.LogInformation("Listing policies for tenant {TenantId}", tenantId);
        var result = await mediator.Send(new GetPoliciesQuery(tenantId.Value));

        if (!result.IsSuccess)
            return Results.BadRequest(ApiResponse<object>.FailureResponse(result.Error!));

        return Results.Ok(ApiResponse<object>.SuccessResponse(result.Value!));
    }

    public static async Task<IResult> GetAvailableTemplates(
        [FromServices] IMediator mediator,
        [FromServices] ILogger<PolicyEndpointsLogCategory> logger)
    {
        logger.LogInformation("Listing available ABAC condition templates");
        var result = await mediator.Send(new GetAvailableTemplatesQuery());

        if (!result.IsSuccess)
            return Results.BadRequest(ApiResponse<object>.FailureResponse(result.Error!));

        return Results.Ok(ApiResponse<object>.SuccessResponse(result.Value!));
    }

    public static async Task<IResult> CreatePolicy(
        [FromBody] CreatePolicyRequest request,
        [FromServices] IMediator mediator,
        [FromServices] ICurrentUser currentUser,
        [FromServices] ILogger<PolicyEndpointsLogCategory> logger)
    {
        var tenantId = currentUser.TenantId;
        if (tenantId is null)
            return Results.BadRequest(ApiResponse<object>.FailureResponse("No tenant selected."));

        logger.LogInformation(
            "Admin creating policy '{Name}' ({ResourceType}/{Action}) for tenant {TenantId}",
            request.Name, request.ResourceType, request.Action, tenantId);

        var conditions = request.Conditions
            .Select(c => new PolicyConditionDto(c.TemplateName, c.Parameters))
            .ToList();

        var result = await mediator.Send(
            new CreatePolicyCommand(PolicyScope.Tenant, tenantId.Value, request.Name, request.Description, request.ResourceType, request.Action, conditions));

        if (!result.IsSuccess)
            return Results.BadRequest(ApiResponse<object>.FailureResponse(result.Error!));

        return Results.Ok(ApiResponse<object>.SuccessResponse(result.Value!));
    }

    public static async Task<IResult> UpdatePolicy(
        Guid policyId,
        [FromBody] UpdatePolicyRequest request,
        [FromServices] IMediator mediator,
        [FromServices] ILogger<PolicyEndpointsLogCategory> logger)
    {
        logger.LogInformation("Admin updating policy {PolicyId}", policyId);

        var conditions = request.Conditions
            .Select(c => new PolicyConditionDto(c.TemplateName, c.Parameters))
            .ToList();

        var result = await mediator.Send(new UpdatePolicyCommand(policyId, request.Name, request.Description, conditions));

        if (!result.IsSuccess)
            return Results.BadRequest(ApiResponse<object>.FailureResponse(result.Error!));

        return Results.Ok(ApiResponse<object>.SuccessResponse(result.Value!));
    }

    public static async Task<IResult> DeletePolicy(
        Guid policyId,
        [FromServices] IMediator mediator,
        [FromServices] ILogger<PolicyEndpointsLogCategory> logger)
    {
        logger.LogInformation("Admin deleting policy {PolicyId}", policyId);

        var result = await mediator.Send(new DeletePolicyCommand(policyId));

        if (!result.IsSuccess)
            return Results.BadRequest(ApiResponse<object>.FailureResponse(result.Error!));

        return Results.Ok(ApiResponse<object>.SuccessResponse(result.Value!));
    }
}
