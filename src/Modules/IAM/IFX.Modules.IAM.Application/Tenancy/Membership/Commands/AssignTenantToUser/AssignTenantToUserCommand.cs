using IFX.BuildingBlocks.Application.Commands;
using IFX.Modules.IAM.Application.Transactions;
using IFX.Modules.IAM.Application.Common;
using MediatR;

namespace IFX.Modules.IAM.Application.Tenancy.Membership.Commands.AssignTenantToUser;

public record AssignTenantToUserCommand(Guid UserId, Guid TenantId, bool SetAsPrimary = false) : ICommand<Result<bool>, AuthTransactionOwner>;
