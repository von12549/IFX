using IFX.Modules.Auth.Application.Authorization.DTOs;
using IFX.Modules.Auth.Application.Common;
using MediatR;

namespace IFX.Modules.Auth.Application.Authorization.Queries.GetAllRoles;

public record GetAllRolesQuery(Guid? TenantId = null) : IRequest<Result<List<RoleDto>>>;
