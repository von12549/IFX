using IFX.Modules.IAM.Application.Common;
using IFX.Modules.IAM.Application.Common.DTOs;
using IFX.Modules.IAM.Application.Users.DTOs;
using MediatR;

namespace IFX.Modules.IAM.Application.Users.Queries.GetAllUsersAcrossTenants;

public record GetAllUsersAcrossTenantsQuery : IRequest<Result<CrossTenantResultDto<UserProfileDto>>>;
