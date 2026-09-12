using IFX.Modules.IAM.Application.Common;
using IFX.Modules.IAM.Application.Common.DTOs;
using IFX.Modules.IAM.Application.Identity.DTOs;
using MediatR;

namespace IFX.Modules.IAM.Application.Identity.Queries.GetAllIdpsAcrossTenants;

public record GetAllIdpsAcrossTenantsQuery : IRequest<Result<CrossTenantResultDto<IdpDto>>>;
