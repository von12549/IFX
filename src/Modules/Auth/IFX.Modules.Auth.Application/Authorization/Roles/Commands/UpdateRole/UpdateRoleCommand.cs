using IFX.BuildingBlocks.Application.Commands;
using IFX.Modules.Auth.Application.Transactions;
using IFX.Modules.Auth.Application.Authorization.Roles.DTOs;
using IFX.Modules.Auth.Application.Common;
using MediatR;

namespace IFX.Modules.Auth.Application.Authorization.Roles.Commands.UpdateRole;

public record UpdateRoleCommand(Guid RoleId, string Name, string Description, Guid TenantId) : ICommand<Result<RoleDto>, AuthTransactionOwner>;
