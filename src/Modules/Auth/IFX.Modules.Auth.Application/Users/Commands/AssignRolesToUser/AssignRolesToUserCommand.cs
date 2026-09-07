using IFX.BuildingBlocks.Application.Commands;
using IFX.Modules.Auth.Application.Transactions;
using IFX.Modules.Auth.Application.Common;
using MediatR;

namespace IFX.Modules.Auth.Application.Users.Commands.AssignRolesToUser;

public record AssignRolesToUserCommand(Guid UserId, List<Guid> RoleIds) : ICommand<Result<bool>, AuthTransactionOwner>;
