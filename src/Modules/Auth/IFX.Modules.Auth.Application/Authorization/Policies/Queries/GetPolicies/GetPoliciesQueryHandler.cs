using System.Text.Json;
using IFX.Modules.Auth.Application.Authorization.Policies.DTOs;
using IFX.Modules.Auth.Application.Common;
using IFX.Modules.Auth.Application.Interfaces;
using IFX.Modules.Auth.Domain.Authorization;
using MediatR;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.Auth.Application.Authorization.Policies.Queries.GetPolicies;

public class GetPoliciesQueryHandler : IRequestHandler<GetPoliciesQuery, Result<List<PolicyDefinitionDto>>>
{
    private readonly IUnitOfWork _unitOfWork;
    private readonly ILogger<GetPoliciesQueryHandler> _logger;

    public GetPoliciesQueryHandler(
        IUnitOfWork unitOfWork,
        ILogger<GetPoliciesQueryHandler> logger)
    {
        _unitOfWork = unitOfWork;
        _logger = logger;
    }

    public async Task<Result<List<PolicyDefinitionDto>>> Handle(
        GetPoliciesQuery request, CancellationToken cancellationToken)
    {
        try
        {
            var tenantRows = await _unitOfWork.PolicyDefinitions
                .GetByTenantIdAsync(request.TenantId, cancellationToken);

            var result = tenantRows.Select(MapToDto).ToList();

            // Note: To show platform defaults (not overridden), modules would register defaults
            // on StaticAbacPolicyResolver. We surface tenant rows for now; a future enhancement
            // can merge with static defaults for a full merged view.

            return Result<List<PolicyDefinitionDto>>.Success(result);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error retrieving policies for tenant {TenantId}", request.TenantId);
            return Result<List<PolicyDefinitionDto>>.Failure("An error occurred while retrieving policies.");
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
