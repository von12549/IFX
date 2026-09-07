using IFX.BuildingBlocks.Application.Commands;
using IFX.Modules.Auth.Application.Transactions;
using IFX.Modules.Auth.Application.Authorization.RoleGroups.DTOs;
using IFX.Modules.Auth.Application.Common;
using MediatR;

namespace IFX.Modules.Auth.Application.Authorization.RoleGroups.Commands.AssignRolesToRoleGroup;

public record AssignRolesToRoleGroupCommand(Guid RoleGroupId, List<Guid> RoleIds) : ICommand<Result<RoleGroupDto>, AuthTransactionOwner>;
