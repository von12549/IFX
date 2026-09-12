using IFX.BuildingBlocks.Application.Commands;
using IFX.Modules.IAM.Application.Transactions;
using IFX.Modules.IAM.Application.Common;
using IFX.Modules.IAM.Application.Identity.DTOs;
using MediatR;

namespace IFX.Modules.IAM.Application.Identity.Commands.RefreshToken;

public record RefreshTokenCommand(
    string RefreshToken,
    string Username,
    string? IpAddress = null) : ICommand<Result<RefreshTokenResponse>, AuthTransactionOwner>;
