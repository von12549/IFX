using IFX.BuildingBlocks.Application.Commands;
using IFX.Modules.Auth.Application.Transactions;
using IFX.Modules.Auth.Application.Common;
using MediatR;

namespace IFX.Modules.Auth.Application.Users.Commands.AssignTenantToUser;

public record AssignTenantToUserCommand(Guid UserId, Guid TenantId, bool SetAsPrimary = false) : ICommand<Result<bool>, AuthTransactionOwner>;
