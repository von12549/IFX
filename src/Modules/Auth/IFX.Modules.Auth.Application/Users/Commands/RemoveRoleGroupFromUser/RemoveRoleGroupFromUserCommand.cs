using IFX.BuildingBlocks.Application.Commands;
using IFX.Modules.Auth.Application.Transactions;
using IFX.Modules.Auth.Application.Common;
using MediatR;

namespace IFX.Modules.Auth.Application.Users.Commands.RemoveRoleGroupFromUser;

public record RemoveRoleGroupFromUserCommand(Guid UserId, Guid RoleGroupId) : ICommand<Result<bool>, AuthTransactionOwner>;
