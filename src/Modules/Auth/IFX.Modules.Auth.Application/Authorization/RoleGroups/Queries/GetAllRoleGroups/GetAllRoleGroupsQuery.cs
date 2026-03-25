using IFX.Modules.Auth.Application.Authorization.RoleGroups.DTOs;
using IFX.Modules.Auth.Application.Common;
using MediatR;

namespace IFX.Modules.Auth.Application.Authorization.RoleGroups.Queries.GetAllRoleGroups;

public record GetAllRoleGroupsQuery : IRequest<Result<List<RoleGroupDto>>>;
