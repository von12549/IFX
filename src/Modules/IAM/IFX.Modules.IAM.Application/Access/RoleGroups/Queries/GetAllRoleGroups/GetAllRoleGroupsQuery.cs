using IFX.Modules.IAM.Application.Access.RoleGroups.DTOs;
using IFX.Modules.IAM.Application.Common;
using MediatR;

namespace IFX.Modules.IAM.Application.Access.RoleGroups.Queries.GetAllRoleGroups;

public record GetAllRoleGroupsQuery : IRequest<Result<List<RoleGroupDto>>>;
