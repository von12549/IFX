using IFX.Modules.Auth.Application.Authorization.DTOs;
using IFX.Modules.Auth.Application.Common;
using MediatR;

namespace IFX.Modules.Auth.Application.Authorization.Queries.GetAllTenants;

public record GetAllTenantsQuery : IRequest<Result<List<TenantDto>>>;
