using IFX.Modules.IAM.Application.Tenancy.Tenants.DTOs;
using IFX.Modules.IAM.Application.Common;
using MediatR;

namespace IFX.Modules.IAM.Application.Tenancy.Tenants.Queries.GetAllTenants;

public record GetAllTenantsQuery : IRequest<Result<List<TenantDto>>>;
