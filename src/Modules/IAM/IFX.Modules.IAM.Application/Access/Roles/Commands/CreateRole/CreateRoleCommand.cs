using IFX.BuildingBlocks.Application.Commands;
using IFX.Modules.IAM.Application.Transactions;
using IFX.Modules.IAM.Application.Access.Roles.DTOs;
using IFX.Modules.IAM.Application.Common;
using MediatR;

namespace IFX.Modules.IAM.Application.Access.Roles.Commands.CreateRole;

public record CreateRoleCommand(string Name, string Description, Guid TenantId) : ICommand<Result<RoleDto>, AuthTransactionOwner>
{
    public IFX.BuildingBlocks.Application.Transactions.TransactionProfile TransactionProfile => IFX.BuildingBlocks.Application.Transactions.TransactionProfile.ConsistentReadWrite;
}
