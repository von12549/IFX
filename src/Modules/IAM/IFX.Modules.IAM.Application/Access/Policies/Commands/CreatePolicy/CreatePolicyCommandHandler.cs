using System.Text.Json;
using IFX.BuildingBlocks.Security.Authorization.Abac.Resolver;
using IFX.BuildingBlocks.Security.Authorization;
using IFX.Modules.IAM.Application.Access.Policies.DTOs;
using IFX.Modules.IAM.Application.Common;
using IFX.Modules.IAM.Application.Common.Authorization;
using IFX.Modules.IAM.Application.Interfaces;
using IFX.Modules.IAM.Domain.Access;
using IFX.Modules.IAM.Domain.Tenancy;
using MediatR;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.IAM.Application.Access.Policies.Commands.CreatePolicy;
public class CreatePolicyCommandHandler : IRequestHandler<CreatePolicyCommand, Result<PolicyDefinitionDto>>
{
    private readonly IUnitOfWork _unitOfWork;
    private readonly ICurrentUser _currentUser;
    private readonly IResourceAuthorizationService _authorizationService;
    private readonly IAbacPolicyCache _policyCache;
    private readonly ILogger<CreatePolicyCommandHandler> _logger;
    public CreatePolicyCommandHandler(IUnitOfWork unitOfWork, ICurrentUser currentUser, IResourceAuthorizationService authorizationService, IAbacPolicyCache policyCache, ILogger<CreatePolicyCommandHandler> logger)
    {
        _unitOfWork = unitOfWork;
        _currentUser = currentUser;
        _authorizationService = authorizationService;
        _policyCache = policyCache;
        _logger = logger;
    }

    public async Task<Result<PolicyDefinitionDto>> Handle(CreatePolicyCommand request, CancellationToken cancellationToken)
    {
        {
            await _authorizationService.AuthorizeWithResolvedPolicyAsync("policy", "create", new TenantScopeResourceAttributes(_currentUser.TenantId), ct: cancellationToken);
            var alreadyExists = request.Scope == PolicyScope.Platform ? await _unitOfWork.PolicyDefinitions.ExistsPlatformAsync(request.ResourceType, request.Action, cancellationToken) : await _unitOfWork.PolicyDefinitions.ExistsAsync(request.TenantId!.Value, request.ResourceType, request.Action, cancellationToken);
            if (alreadyExists)
                return Result<PolicyDefinitionDto>.Failure($"A policy for '{request.ResourceType}/{request.Action}' already exists{(request.Scope == PolicyScope.Platform ? " at platform level" : " for this tenant")}.");
            var conditionsJson = JsonSerializer.Serialize(request.Conditions.Select(c => new PolicyConditionRecord(c.TemplateName, c.Parameters)).ToList());
            var policy = PolicyDefinition.Create(request.Scope, request.TenantId, request.Name, request.ResourceType, request.Action, conditionsJson, _currentUser.UserId, request.Description);
            await _unitOfWork.PolicyDefinitions.AddAsync(policy, cancellationToken);
            if (request.Scope == PolicyScope.Platform)
                _policyCache.InvalidatePlatform(request.ResourceType, request.Action);
            else
                _policyCache.Invalidate(request.TenantId!.Value, request.ResourceType, request.Action);
            _logger.LogInformation("Policy created: {PolicyId} for {Scope} ({ResourceType}/{Action})", policy.Id, request.Scope, request.ResourceType, request.Action);
            return Result<PolicyDefinitionDto>.Success(MapToDto(policy));
        }
    }

    private static PolicyDefinitionDto MapToDto(PolicyDefinition p)
    {
        var conditions = JsonSerializer.Deserialize<List<PolicyConditionRecord>>(p.ConditionsJson, new JsonSerializerOptions { PropertyNameCaseInsensitive = true }) ?? [];
        return new PolicyDefinitionDto(p.Id, p.TenantId, p.Name, p.Description, p.ResourceType, p.Action, conditions.Select(c => new PolicyConditionDto(c.TemplateName, c.Parameters)).ToList(), p.IsActive, IsPlatformDefault: p.Scope == PolicyScope.Platform, p.UpdatedAt, p.Scope);
    }
}
