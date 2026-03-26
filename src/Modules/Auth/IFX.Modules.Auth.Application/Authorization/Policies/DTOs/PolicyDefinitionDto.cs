using IFX.Modules.Auth.Domain.Authorization;

namespace IFX.Modules.Auth.Application.Authorization.Policies.DTOs;

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
    DateTime UpdatedAt,
    PolicyScope Scope = PolicyScope.Tenant);
