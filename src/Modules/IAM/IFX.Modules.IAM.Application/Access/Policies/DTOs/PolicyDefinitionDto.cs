using IFX.Modules.IAM.Domain.Access;
using IFX.Modules.IAM.Domain.Tenancy;

namespace IFX.Modules.IAM.Application.Access.Policies.DTOs;

public record PolicyDefinitionDto(
    Guid? Id,
    Guid? TenantId,
    string Name,
    string? Description,
    string ResourceType,
    string Action,
    List<PolicyConditionDto> Conditions,
    bool IsActive,
    bool IsPlatformDefault,
    DateTimeOffset UpdatedAt,
    PolicyScope Scope = PolicyScope.Tenant);
