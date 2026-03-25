using IFX.Modules.Auth.Application.Common;
using MediatR;

namespace IFX.Modules.Auth.Application.Authorization.Tenants.Commands.DeleteTenant;

public record DeleteTenantCommand(Guid TenantId) : IRequest<Result<bool>>;
