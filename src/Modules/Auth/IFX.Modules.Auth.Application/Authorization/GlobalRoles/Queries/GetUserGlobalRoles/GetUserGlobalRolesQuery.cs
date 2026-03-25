using IFX.Modules.Auth.Application.Authorization.GlobalRoles.DTOs;
using IFX.Modules.Auth.Application.Common;
using MediatR;

namespace IFX.Modules.Auth.Application.Authorization.GlobalRoles.Queries.GetUserGlobalRoles;

public record GetUserGlobalRolesQuery(Guid UserId) : IRequest<Result<List<GlobalRoleDto>>>;
