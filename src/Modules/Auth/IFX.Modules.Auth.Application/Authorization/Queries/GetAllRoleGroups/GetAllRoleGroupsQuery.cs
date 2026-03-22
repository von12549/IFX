using IFX.Modules.Auth.Application.Authorization.DTOs;
using IFX.Modules.Auth.Application.Common;
using MediatR;

namespace IFX.Modules.Auth.Application.Authorization.Queries.GetAllRoleGroups;

public record GetAllRoleGroupsQuery(Guid? TenantId = null) : IRequest<Result<List<RoleGroupDto>>>;
