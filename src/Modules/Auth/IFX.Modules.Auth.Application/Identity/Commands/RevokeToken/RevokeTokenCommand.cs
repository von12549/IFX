using IFX.BuildingBlocks.Application.Commands;
using IFX.Modules.Auth.Application.Transactions;
using IFX.Modules.Auth.Application.Common;
using MediatR;

namespace IFX.Modules.Auth.Application.Identity.Commands.RevokeToken;

public record RevokeTokenCommand(
    string RefreshToken,
    string? Email = null,
    string? IpAddress = null) : ICommand<Result<bool>, AuthTransactionOwner>;
