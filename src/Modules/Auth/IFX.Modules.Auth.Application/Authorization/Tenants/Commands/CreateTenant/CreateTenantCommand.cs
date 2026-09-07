using IFX.BuildingBlocks.Application.Commands;
using IFX.Modules.Auth.Application.Transactions;
using IFX.Modules.Auth.Application.Authorization.Tenants.DTOs;
using IFX.Modules.Auth.Application.Common;
using MediatR;

namespace IFX.Modules.Auth.Application.Authorization.Tenants.Commands.CreateTenant;

public record CreateTenantCommand(string Name, string Description) : ICommand<Result<TenantDto>, AuthTransactionOwner>;
