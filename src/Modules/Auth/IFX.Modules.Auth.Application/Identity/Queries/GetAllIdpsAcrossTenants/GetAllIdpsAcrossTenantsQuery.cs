using IFX.Modules.Auth.Application.Common;
using IFX.Modules.Auth.Application.Common.DTOs;
using IFX.Modules.Auth.Application.Identity.DTOs;
using MediatR;

namespace IFX.Modules.Auth.Application.Identity.Queries.GetAllIdpsAcrossTenants;

public record GetAllIdpsAcrossTenantsQuery : IRequest<Result<CrossTenantResultDto<IdpDto>>>;
