using IFX.Modules.Auth.Application.Authorization.Roles.DTOs;
using IFX.Modules.Auth.Application.Common;
using MediatR;

namespace IFX.Modules.Auth.Application.Authorization.Roles.Queries.GetRoleById;

public record GetRoleByIdQuery(Guid RoleId) : IRequest<Result<RoleDetailDto>>;
