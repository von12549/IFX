using IFX.Modules.Auth.Application.Authorization.Tenants.DTOs;
using IFX.Modules.Auth.Application.Common;
using MediatR;

namespace IFX.Modules.Auth.Application.Authorization.Tenants.Queries.GetAllTenants;

public record GetAllTenantsQuery : IRequest<Result<List<TenantDto>>>;
