using IFX.Modules.IAM.Application.Access.GlobalRoles.DTOs;
using IFX.Modules.IAM.Application.Common;
using MediatR;

namespace IFX.Modules.IAM.Application.Access.GlobalRoles.Queries.ListGlobalRoles;

public record ListGlobalRolesQuery : IRequest<Result<List<GlobalRoleDto>>>;
