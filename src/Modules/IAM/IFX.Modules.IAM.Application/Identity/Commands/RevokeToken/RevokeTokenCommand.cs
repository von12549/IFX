using IFX.BuildingBlocks.Application.Commands;
using IFX.Modules.IAM.Application.Transactions;
using IFX.Modules.IAM.Application.Common;
using MediatR;

namespace IFX.Modules.IAM.Application.Identity.Commands.RevokeToken;

public record RevokeTokenCommand(
    string RefreshToken,
    string? Email = null,
    string? IpAddress = null) : ICommand<Result<bool>, AuthTransactionOwner>;
