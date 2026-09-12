using IFX.BuildingBlocks.Application.Commands;
using IFX.Modules.IAM.Application.Transactions;
using IFX.Modules.IAM.Application.Common;
using MediatR;

namespace IFX.Modules.IAM.Application.Identity.Commands.LogoutUser;

public record LogoutUserCommand(
    string Issuer,
    string Subject,
    string AccessToken,
    string IpAddress) : ICommand<Result<bool>, IamTransactionOwner>;
