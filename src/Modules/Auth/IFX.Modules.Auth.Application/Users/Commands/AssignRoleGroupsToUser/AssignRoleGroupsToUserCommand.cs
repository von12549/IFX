using IFX.BuildingBlocks.Application.Commands;
using IFX.Modules.Auth.Application.Transactions;
using IFX.Modules.Auth.Application.Common;
using MediatR;

namespace IFX.Modules.Auth.Application.Users.Commands.AssignRoleGroupsToUser;

public record AssignRoleGroupsToUserCommand(Guid UserId, List<Guid> RoleGroupIds) : ICommand<Result<bool>, AuthTransactionOwner>;
