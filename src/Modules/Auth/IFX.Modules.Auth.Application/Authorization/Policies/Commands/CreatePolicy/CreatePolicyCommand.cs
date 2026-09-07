using IFX.BuildingBlocks.Application.Commands;
using IFX.Modules.Auth.Application.Transactions;
using IFX.Modules.Auth.Application.Authorization.Policies.DTOs;
using IFX.Modules.Auth.Application.Common;
using IFX.Modules.Auth.Domain.Authorization;
using MediatR;

namespace IFX.Modules.Auth.Application.Authorization.Policies.Commands.CreatePolicy;

public record CreatePolicyCommand(
    PolicyScope Scope,
    Guid? TenantId,
    string Name,
    string? Description,
    string ResourceType,
    string Action,
    List<PolicyConditionDto> Conditions) : ICommand<Result<PolicyDefinitionDto>, AuthTransactionOwner>;
