using IFX.BuildingBlocks.Application.Commands;
using IFX.Modules.IAM.Application.Transactions;
using IFX.Modules.IAM.Application.Common;
using MediatR;

namespace IFX.Modules.IAM.Application.Access.RoleGroups.Commands.RemoveRoleFromRoleGroup;

public record RemoveRoleFromRoleGroupCommand(Guid RoleGroupId, Guid RoleId) : ICommand<Result<bool>, AuthTransactionOwner>
{
    public IFX.BuildingBlocks.Application.Transactions.TransactionProfile TransactionProfile => IFX.BuildingBlocks.Application.Transactions.TransactionProfile.ConsistentReadWrite;
}
