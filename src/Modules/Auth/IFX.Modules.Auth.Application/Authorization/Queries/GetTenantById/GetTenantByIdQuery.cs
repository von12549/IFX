using IFX.Modules.Auth.Application.Authorization.DTOs;
using IFX.Modules.Auth.Application.Common;
using MediatR;

namespace IFX.Modules.Auth.Application.Authorization.Queries.GetTenantById;

public record GetTenantByIdQuery(Guid TenantId) : IRequest<Result<TenantDto>>;
