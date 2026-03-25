using IFX.Modules.Auth.Application.Authorization.GlobalRoles.DTOs;
using IFX.Modules.Auth.Application.Common;
using MediatR;

namespace IFX.Modules.Auth.Application.Authorization.GlobalRoles.Queries.ListGlobalRoles;

public record ListGlobalRolesQuery : IRequest<Result<List<GlobalRoleDto>>>;
