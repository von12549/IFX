using IFX.Modules.Auth.Application.Authorization.Policies.DTOs;
using IFX.Modules.Auth.Application.Common;
using MediatR;

namespace IFX.Modules.Auth.Application.Authorization.Policies.Commands.CreatePolicy;

public record CreatePolicyCommand(
    Guid TenantId,
    string Name,
    string ResourceType,
    string Action,
    List<PolicyConditionDto> Conditions) : IRequest<Result<PolicyDefinitionDto>>;
