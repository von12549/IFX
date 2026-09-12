using IFX.Modules.IAM.Application.Tenancy.Tenants.DTOs;
using IFX.Modules.IAM.Application.Common;
using MediatR;

namespace IFX.Modules.IAM.Application.Tenancy.Tenants.Queries.GetTenantById;

public record GetTenantByIdQuery(Guid TenantId) : IRequest<Result<TenantDto>>;
