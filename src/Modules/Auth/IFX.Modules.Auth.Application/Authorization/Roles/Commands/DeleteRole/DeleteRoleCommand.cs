using IFX.BuildingBlocks.Application.Commands;
using IFX.Modules.Auth.Application.Transactions;
using IFX.Modules.Auth.Application.Common;
using MediatR;

namespace IFX.Modules.Auth.Application.Authorization.Roles.Commands.DeleteRole;

public record DeleteRoleCommand(Guid RoleId) : ICommand<Result<bool>, AuthTransactionOwner>;
