using IFX.Modules.Auth.Application.Common;
using MediatR;

namespace IFX.Modules.Auth.Application.Authorization.Commands.RemoveRoleFromRoleGroup;

public record RemoveRoleFromRoleGroupCommand(Guid RoleGroupId, Guid RoleId) : IRequest<Result<bool>>;
