using IFX.BuildingBlocks.Application.Commands;
using IFX.Modules.IAM.Application.Transactions;
using IFX.Modules.IAM.Application.Common;
using MediatR;

namespace IFX.Modules.IAM.Application.Access.Assignments.Commands.RemoveRoleGroupFromUser;

public record RemoveRoleGroupFromUserCommand(Guid UserId, Guid RoleGroupId) : ICommand<Result<bool>, AuthTransactionOwner>;
