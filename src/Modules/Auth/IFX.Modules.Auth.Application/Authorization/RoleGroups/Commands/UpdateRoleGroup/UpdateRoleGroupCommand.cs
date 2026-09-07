using IFX.BuildingBlocks.Application.Commands;
using IFX.Modules.Auth.Application.Transactions;
using IFX.Modules.Auth.Application.Authorization.RoleGroups.DTOs;
using IFX.Modules.Auth.Application.Common;
using MediatR;

namespace IFX.Modules.Auth.Application.Authorization.RoleGroups.Commands.UpdateRoleGroup;

public record UpdateRoleGroupCommand(Guid RoleGroupId, string Name, string Description, Guid TenantId) : ICommand<Result<RoleGroupDto>, AuthTransactionOwner>;
