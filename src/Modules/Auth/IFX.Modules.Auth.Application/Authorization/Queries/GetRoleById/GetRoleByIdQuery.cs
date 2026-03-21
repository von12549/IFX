using IFX.Modules.Auth.Application.Authorization.DTOs;
using IFX.Modules.Auth.Application.Common;
using MediatR;

namespace IFX.Modules.Auth.Application.Authorization.Queries.GetRoleById;

public record GetRoleByIdQuery(Guid RoleId) : IRequest<Result<RoleDetailDto>>;
