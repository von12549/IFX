using IFX.Modules.IAM.Application.Access.Permissions.DTOs;
using IFX.Modules.IAM.Application.Common;
using MediatR;

namespace IFX.Modules.IAM.Application.Access.Permissions.Queries.GetAllPermissions;

public record GetAllPermissionsQuery() : IRequest<Result<List<PermissionDto>>>;
