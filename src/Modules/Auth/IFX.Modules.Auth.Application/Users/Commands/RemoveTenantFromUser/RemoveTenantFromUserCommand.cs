using IFX.BuildingBlocks.Application.Commands;
using IFX.Modules.Auth.Application.Transactions;
using IFX.Modules.Auth.Application.Common;
using MediatR;

namespace IFX.Modules.Auth.Application.Users.Commands.RemoveTenantFromUser;

public record RemoveTenantFromUserCommand(Guid UserId, Guid TenantId) : ICommand<Result<bool>, AuthTransactionOwner>;
