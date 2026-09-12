using IFX.BuildingBlocks.Application.Commands;
using IFX.Modules.IAM.Application.Transactions;
using IFX.Modules.IAM.Application.Access.Policies.DTOs;
using IFX.Modules.IAM.Application.Common;
using MediatR;

namespace IFX.Modules.IAM.Application.Access.Policies.Commands.UpdatePolicy;

public record UpdatePolicyCommand(
    Guid PolicyId,
    string Name,
    string? Description,
    List<PolicyConditionDto> Conditions) : ICommand<Result<PolicyDefinitionDto>, IamTransactionOwner>;
