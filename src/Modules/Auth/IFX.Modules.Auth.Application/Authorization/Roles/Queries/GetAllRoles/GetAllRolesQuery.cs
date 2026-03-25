using IFX.Modules.Auth.Application.Authorization.Roles.DTOs;
using IFX.Modules.Auth.Application.Common;
using MediatR;

namespace IFX.Modules.Auth.Application.Authorization.Roles.Queries.GetAllRoles;

public record GetAllRolesQuery : IRequest<Result<List<RoleDto>>>;
