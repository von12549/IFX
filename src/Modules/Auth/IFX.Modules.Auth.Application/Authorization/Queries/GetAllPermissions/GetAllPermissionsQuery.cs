using IFX.Modules.Auth.Application.Authorization.DTOs;
using IFX.Modules.Auth.Application.Common;
using MediatR;

namespace IFX.Modules.Auth.Application.Authorization.Queries.GetAllPermissions;

public record GetAllPermissionsQuery() : IRequest<Result<List<PermissionDto>>>;
