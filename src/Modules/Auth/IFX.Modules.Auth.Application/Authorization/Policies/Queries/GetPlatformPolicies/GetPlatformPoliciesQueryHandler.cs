using System.Text.Json;
using IFX.Modules.Auth.Application.Authorization.Policies.DTOs;
using IFX.Modules.Auth.Application.Common;
using IFX.Modules.Auth.Application.Interfaces;
using IFX.Modules.Auth.Domain.Authorization;
using MediatR;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.Auth.Application.Authorization.Policies.Queries.GetPlatformPolicies;

public class GetPlatformPoliciesQueryHandler : IRequestHandler<GetPlatformPoliciesQuery, Result<List<PolicyDefinitionDto>>>
{
    private readonly IUnitOfWork _unitOfWork;
    private readonly ILogger<GetPlatformPoliciesQueryHandler> _logger;

    public GetPlatformPoliciesQueryHandler(
        IUnitOfWork unitOfWork,
        ILogger<GetPlatformPoliciesQueryHandler> logger)
    {
        _unitOfWork = unitOfWork;
        _logger = logger;
    }

    public async Task<Result<List<PolicyDefinitionDto>>> Handle(
        GetPlatformPoliciesQuery request, CancellationToken cancellationToken)
    {
        try
        {
            var rows = await _unitOfWork.PolicyDefinitions.GetPlatformPoliciesAsync(cancellationToken);
            return Result<List<PolicyDefinitionDto>>.Success(rows.Select(MapToDto).ToList());
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error retrieving platform policies");
            return Result<List<PolicyDefinitionDto>>.Failure("An error occurred while retrieving platform policies.");
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
            IsPlatformDefault: true,
            p.UpdatedAt,
            p.Scope);
    }
}
