using IFX.Modules.Auth.Application.Common;
using IFX.Modules.Auth.Application.DTOs;
using MediatR;

namespace IFX.Modules.Auth.Application.Queries.GetAllRoles;

public record GetAllRolesQuery() : IRequest<Result<List<UserRoleDto>>>;
