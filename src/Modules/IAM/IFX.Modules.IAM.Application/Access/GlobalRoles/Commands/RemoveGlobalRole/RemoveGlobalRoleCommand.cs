using IFX.BuildingBlocks.Application.Commands;
using IFX.Modules.IAM.Application.Transactions;
using IFX.Modules.IAM.Application.Common;
using MediatR;

namespace IFX.Modules.IAM.Application.Access.GlobalRoles.Commands.RemoveGlobalRole;

public record RemoveGlobalRoleCommand(Guid UserId, Guid GlobalRoleId) : ICommand<Result<bool>, IamTransactionOwner>;
