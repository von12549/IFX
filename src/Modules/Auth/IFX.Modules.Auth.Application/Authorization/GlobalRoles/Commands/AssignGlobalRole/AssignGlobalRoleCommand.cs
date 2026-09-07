using IFX.BuildingBlocks.Application.Commands;
using IFX.Modules.Auth.Application.Transactions;
using IFX.Modules.Auth.Application.Common;
using MediatR;

namespace IFX.Modules.Auth.Application.Authorization.GlobalRoles.Commands.AssignGlobalRole;

public record AssignGlobalRoleCommand(Guid UserId, Guid GlobalRoleId) : ICommand<Result<bool>, AuthTransactionOwner>;
