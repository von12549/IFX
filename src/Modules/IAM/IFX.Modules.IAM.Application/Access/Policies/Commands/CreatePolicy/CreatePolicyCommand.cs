using IFX.BuildingBlocks.Application.Commands;
using IFX.Modules.IAM.Application.Transactions;
using IFX.Modules.IAM.Application.Access.Policies.DTOs;
using IFX.Modules.IAM.Application.Common;
using IFX.Modules.IAM.Domain.Access;
using IFX.Modules.IAM.Domain.Tenancy;
using MediatR;

namespace IFX.Modules.IAM.Application.Access.Policies.Commands.CreatePolicy;

public record CreatePolicyCommand(
    PolicyScope Scope,
    Guid? TenantId,
    string Name,
    string? Description,
    string ResourceType,
    string Action,
    List<PolicyConditionDto> Conditions) : ICommand<Result<PolicyDefinitionDto>, IamTransactionOwner>;
