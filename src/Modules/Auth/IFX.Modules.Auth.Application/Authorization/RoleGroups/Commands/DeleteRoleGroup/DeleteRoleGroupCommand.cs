using IFX.BuildingBlocks.Application.Commands;
using IFX.Modules.Auth.Application.Transactions;
using IFX.Modules.Auth.Application.Common;
using MediatR;

namespace IFX.Modules.Auth.Application.Authorization.RoleGroups.Commands.DeleteRoleGroup;

public record DeleteRoleGroupCommand(Guid RoleGroupId) : ICommand<Result<bool>, AuthTransactionOwner>;
