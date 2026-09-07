using IFX.BuildingBlocks.Application.Commands;
using IFX.Modules.Auth.Application.Transactions;
using IFX.Modules.Auth.Application.Authorization.Policies.DTOs;
using IFX.Modules.Auth.Application.Common;
using MediatR;

namespace IFX.Modules.Auth.Application.Authorization.Policies.Commands.UpdatePolicy;

public record UpdatePolicyCommand(
    Guid PolicyId,
    string Name,
    string? Description,
    List<PolicyConditionDto> Conditions) : ICommand<Result<PolicyDefinitionDto>, AuthTransactionOwner>;
