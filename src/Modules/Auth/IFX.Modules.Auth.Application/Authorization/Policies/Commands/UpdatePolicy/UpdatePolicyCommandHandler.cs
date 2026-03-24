using System.Text.Json;
using IFX.BuildingBlocks.Security.Authorization.Abac.Resolver;
using IFX.BuildingBlocks.Security.Authorization.Abstractions;
using IFX.Modules.Auth.Application.Authorization.Policies.DTOs;
using IFX.Modules.Auth.Application.Common;
using IFX.Modules.Auth.Application.Interfaces;
using IFX.Modules.Auth.Domain.Authorization;
using MediatR;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.Auth.Application.Authorization.Policies.Commands.UpdatePolicy;

public class UpdatePolicyCommandHandler : IRequestHandler<UpdatePolicyCommand, Result<PolicyDefinitionDto>>
{
    private readonly IUnitOfWork _unitOfWork;
    private readonly ICurrentUser _currentUser;
    private readonly IAbacPolicyCache _policyCache;
    private readonly ILogger<UpdatePolicyCommandHandler> _logger;

    public UpdatePolicyCommandHandler(
        IUnitOfWork unitOfWork,
        ICurrentUser currentUser,
        IAbacPolicyCache policyCache,
        ILogger<UpdatePolicyCommandHandler> logger)
    {
        _unitOfWork = unitOfWork;
        _currentUser = currentUser;
        _policyCache = policyCache;
        _logger = logger;
    }

    public async Task<Result<PolicyDefinitionDto>> Handle(
        UpdatePolicyCommand request, CancellationToken cancellationToken)
    {
        try
        {
            var policy = await _unitOfWork.PolicyDefinitions.GetByIdAsync(request.PolicyId, cancellationToken);
            if (policy is null)
                return Result<PolicyDefinitionDto>.Failure("Policy not found.");

            var conditionsJson = JsonSerializer.Serialize(
                request.Conditions.Select(c => new PolicyConditionRecord(c.TemplateName, c.Parameters)).ToList());

            policy.Update(request.Name, conditionsJson, _currentUser.UserId);
            await _unitOfWork.SaveChangesAsync(cancellationToken);

            _policyCache.Invalidate(policy.TenantId, policy.ResourceType, policy.Action);

            _logger.LogInformation("Policy updated: {PolicyId}", policy.Id);

            return Result<PolicyDefinitionDto>.Success(MapToDto(policy));
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error updating policy {PolicyId}", request.PolicyId);
            return Result<PolicyDefinitionDto>.Failure("An error occurred while updating the policy.");
        }
    }

    private static PolicyDefinitionDto MapToDto(PolicyDefinition p)
    {
        var conditions = JsonSerializer.Deserialize<List<PolicyConditionRecord>>(
            p.ConditionsJson, new JsonSerializerOptions { PropertyNameCaseInsensitive = true }) ?? [];

        return new PolicyDefinitionDto(
            p.Id,
            p.TenantId,
            p.Name,
            p.ResourceType,
            p.Action,
            conditions.Select(c => new PolicyConditionDto(c.TemplateName, c.Parameters)).ToList(),
            p.IsActive,
            IsPlatformDefault: false,
            p.UpdatedAt);
    }
}
