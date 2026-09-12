using IFX.Modules.IAM.Application.Access.Roles.DTOs;
using IFX.Modules.IAM.Application.Common;
using MediatR;

namespace IFX.Modules.IAM.Application.Access.Roles.Queries.GetAllRoles;

public record GetAllRolesQuery : IRequest<Result<List<RoleDto>>>;
