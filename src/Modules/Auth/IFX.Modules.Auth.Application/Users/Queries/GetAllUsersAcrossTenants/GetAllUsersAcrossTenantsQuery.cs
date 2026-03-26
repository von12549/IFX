using IFX.Modules.Auth.Application.Common;
using IFX.Modules.Auth.Application.Common.DTOs;
using IFX.Modules.Auth.Application.Users.DTOs;
using MediatR;

namespace IFX.Modules.Auth.Application.Users.Queries.GetAllUsersAcrossTenants;

public record GetAllUsersAcrossTenantsQuery : IRequest<Result<CrossTenantResultDto<UserProfileDto>>>;
