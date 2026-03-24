using System.Text.Json;
using IFX.BuildingBlocks.Security.Authorization.Abac.Resolver;
using IFX.BuildingBlocks.Security.Authorization.Abstractions;
using IFX.Modules.Auth.Application.Authorization.Policies.DTOs;
using IFX.Modules.Auth.Application.Common;
using IFX.Modules.Auth.Application.Interfaces;
using IFX.Modules.Auth.Domain.Authorization;
using MediatR;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.Auth.Application.Authorization.Policies.Commands.CreatePolicy;

public class CreatePolicyCommandHandler : IRequestHandler<CreatePolicyCommand, Result<PolicyDefinitionDto>>
{
    private readonly IUnitOfWork _unitOfWork;
    private readonly ICurrentUser _currentUser;
    private readonly IAbacPolicyCache _policyCache;
    private readonly ILogger<CreatePolicyCommandHandler> _logger;

    public CreatePolicyCommandHandler(
        IUnitOfWork unitOfWork,
        ICurrentUser currentUser,
        IAbacPolicyCache policyCache,
        ILogger<CreatePolicyCommandHandler> logger)
    {
        _unitOfWork = unitOfWork;
        _currentUser = currentUser;
        _policyCache = policyCache;
        _logger = logger;
    }

    public async Task<Result<PolicyDefinitionDto>> Handle(
        CreatePolicyCommand request, CancellationToken cancellationToken)
    {
        try
        {
            if (await _unitOfWork.PolicyDefinitions.ExistsAsync(
                    request.TenantId, request.ResourceType, request.Action, cancellationToken))
                return Result<PolicyDefinitionDto>.Failure(
                    $"A policy for '{request.ResourceType}/{request.Action}' already exists for this tenant.");

            var conditionsJson = JsonSerializer.Serialize(
                request.Conditions.Select(c => new PolicyConditionRecord(c.TemplateName, c.Parameters)).ToList());

            var policy = PolicyDefinition.Create(
                request.TenantId,
                request.Name,
                request.ResourceType,
                request.Action,
                conditionsJson,
                _currentUser.UserId,
                request.Description);

            await _unitOfWork.PolicyDefinitions.AddAsync(policy, cancellationToken);
            await _unitOfWork.SaveChangesAsync(cancellationToken);

            _policyCache.Invalidate(request.TenantId, request.ResourceType, request.Action);

            _logger.LogInformation(
                "Policy created: {PolicyId} for tenant {TenantId} ({ResourceType}/{Action})",
                policy.Id, request.TenantId, request.ResourceType, request.Action);

            return Result<PolicyDefinitionDto>.Success(MapToDto(policy));
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error creating policy for {ResourceType}/{Action}", request.ResourceType, request.Action);
            return Result<PolicyDefinitionDto>.Failure("An error occurred while creating the policy.");
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
            p.Description,
            p.ResourceType,
            p.Action,
            conditions.Select(c => new PolicyConditionDto(c.TemplateName, c.Parameters)).ToList(),
            p.IsActive,
            IsPlatformDefault: false,
            p.UpdatedAt);
    }
}
