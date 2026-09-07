using IFX.BuildingBlocks.Application.Commands;
using IFX.Modules.Auth.Application.Transactions;
using IFX.Modules.Auth.Application.Common;
using MediatR;

namespace IFX.Modules.Auth.Application.Authorization.Tenants.Commands.DeleteTenant;

public record DeleteTenantCommand(Guid TenantId) : ICommand<Result<bool>, AuthTransactionOwner>;
