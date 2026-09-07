using IFX.BuildingBlocks.Application.Commands;
using IFX.Modules.Auth.Application.Transactions;
using IFX.Modules.Auth.Application.Common;
using IFX.Modules.Auth.Application.Identity.DTOs;
using MediatR;

namespace IFX.Modules.Auth.Application.Identity.Commands.LoginUser;

public record LoginUserCommand(
    string Email,
    string Password,
    string IpAddress,
    string UserAgent) : ICommand<Result<LoginUserResponse>, AuthTransactionOwner>;
