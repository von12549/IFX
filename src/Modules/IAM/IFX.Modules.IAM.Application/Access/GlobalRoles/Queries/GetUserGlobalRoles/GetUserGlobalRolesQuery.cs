using IFX.Modules.IAM.Application.Access.GlobalRoles.DTOs;
using IFX.Modules.IAM.Application.Common;
using MediatR;

namespace IFX.Modules.IAM.Application.Access.GlobalRoles.Queries.GetUserGlobalRoles;

public record GetUserGlobalRolesQuery(Guid UserId) : IRequest<Result<List<GlobalRoleDto>>>;
