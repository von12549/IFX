using IFX.Modules.Auth.Application.Authorization.Tenants.DTOs;
using IFX.Modules.Auth.Application.Common;
using MediatR;

namespace IFX.Modules.Auth.Application.Authorization.Tenants.Commands.UpdateTenant;

public record UpdateTenantCommand(Guid TenantId, string Name, string Description) : IRequest<Result<TenantDto>>;
