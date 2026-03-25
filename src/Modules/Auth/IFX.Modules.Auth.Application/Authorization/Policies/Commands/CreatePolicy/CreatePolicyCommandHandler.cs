using System.Text.Json;
using IFX.BuildingBlocks.Security.Authorization.Abac.Resolver;
using IFX.BuildingBlocks.Security.Authorization.Abstractions;
using IFX.Modules.Auth.Application.Authorization.Policies.DTOs;
using IFX.Modules.Auth.Application.Common;
using IFX.Modules.Auth.Application.Common.Authorization;
using IFX.Modules.Auth.Application.Interfaces;
using IFX.Modules.Auth.Domain.Authorization;
using MediatR;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.Auth.Application.Authorization.Policies.Commands.CreatePolicy;

public class CreatePolicyCommandHandler : IRequestHandler<CreatePolicyCommand, Result<PolicyDefinitionDto>>
{
    private readonly IUnitOfWork _unitOfWork;
    private readonly ICurrentUser _currentUser;
    private readonly IResourceAuthorizationService _authorizationService;
    private readonly IAbacPolicyCache _policyCache;
    private readonly ILogger<CreatePolicyCommandHandler> _logger;

    public CreatePolicyCommandHandler(
        IUnitOfWork unitOfWork,
        ICurrentUser currentUser,
        IResourceAuthorizationService authorizationService,
        IAbacPolicyCache policyCache,
        ILogger<CreatePolicyCommandHandler> logger)
    {
        _unitOfWork = unitOfWork;
        _currentUser = currentUser;
        _authorizationService = authorizationService;
        _policyCache = policyCache;
        _logger = logger;
    }

    public async Task<Result<PolicyDefinitionDto>> Handle(
        CreatePolicyCommand request, CancellationToken cancellationToken)
    {
        try
        {
            await _authorizationService.AuthorizeWithResolvedPolicyAsync(
                "policy", "create",
                new TenantScopeResourceAttributes(_currentUser.TenantId),
                ct: cancellationToken);

            var alreadyExists = request.TenantId is null
                ? await _unitOfWork.PolicyDefinitions.ExistsPlatformAsync(request.ResourceType, request.Action, cancellationToken)
                : await _unitOfWork.PolicyDefinitions.ExistsAsync(request.TenantId.Value, request.ResourceType, request.Action, cancellationToken);

            if (alreadyExists)
                return Result<PolicyDefinitionDto>.Failure(
                    $"A policy for '{request.ResourceType}/{request.Action}' already exists{(request.TenantId is null ? " at platform level" : " for this tenant")}.");

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

            if (request.TenantId is null)
                _policyCache.InvalidatePlatform(request.ResourceType, request.Action);
            else
                _policyCache.Invalidate(request.TenantId.Value, request.ResourceType, request.Action);

            _logger.LogInformation(
                "Policy created: {PolicyId} for {Scope} ({ResourceType}/{Action})",
                policy.Id, request.TenantId is null ? "platform" : request.TenantId, request.ResourceType, request.Action);

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
            IsPlatformDefault: p.TenantId is null,
            p.UpdatedAt);
    }
}
