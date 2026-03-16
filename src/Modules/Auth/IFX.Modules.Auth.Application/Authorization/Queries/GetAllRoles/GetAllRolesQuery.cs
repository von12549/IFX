using IFX.Modules.Auth.Application.Common;
using IFX.Modules.Auth.Application.Authorization.DTOs;
using MediatR;

namespace IFX.Modules.Auth.Application.Authorization.Queries.GetAllRoles;

public record GetAllRolesQuery() : IRequest<Result<List<UserRoleDto>>>;
