using IFX.BuildingBlocks.Application.Commands;
using IFX.Modules.IAM.Application.Transactions;
using IFX.Modules.IAM.Application.Tenancy.Tenants.DTOs;
using IFX.Modules.IAM.Application.Common;
using MediatR;

namespace IFX.Modules.IAM.Application.Tenancy.Tenants.Commands.UpdateTenant;

public record UpdateTenantCommand(Guid TenantId, string Name, string Description, bool? IsActive = null) : ICommand<Result<TenantDto>, AuthTransactionOwner>
{
    public IFX.BuildingBlocks.Application.Transactions.TransactionProfile TransactionProfile => IFX.BuildingBlocks.Application.Transactions.TransactionProfile.ConsistentReadWrite;
}
