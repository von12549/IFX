using IFX.Modules.Auth.Application.Authorization.DTOs;
using IFX.Modules.Auth.Application.Common;
using MediatR;

namespace IFX.Modules.Auth.Application.Authorization.Commands.CreateTenant;

public record CreateTenantCommand(string Name, string Description) : IRequest<Result<TenantDto>>;
