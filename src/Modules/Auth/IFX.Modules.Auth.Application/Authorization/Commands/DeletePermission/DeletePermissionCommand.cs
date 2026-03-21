using IFX.Modules.Auth.Application.Common;
using MediatR;

namespace IFX.Modules.Auth.Application.Authorization.Commands.DeletePermission;

public record DeletePermissionCommand(Guid PermissionId) : IRequest<Result<bool>>;
