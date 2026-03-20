using IFX.Modules.Auth.Application.Common;
using MediatR;

namespace IFX.Modules.Auth.Application.Authorization.Commands.DeleteRoleGroup;

public record DeleteRoleGroupCommand(Guid RoleGroupId) : IRequest<Result<bool>>;
