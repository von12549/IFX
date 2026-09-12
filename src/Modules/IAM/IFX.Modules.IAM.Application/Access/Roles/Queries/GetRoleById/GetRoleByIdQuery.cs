using IFX.Modules.IAM.Application.Access.Roles.DTOs;
using IFX.Modules.IAM.Application.Common;
using MediatR;

namespace IFX.Modules.IAM.Application.Access.Roles.Queries.GetRoleById;

public record GetRoleByIdQuery(Guid RoleId) : IRequest<Result<RoleDetailDto>>;
