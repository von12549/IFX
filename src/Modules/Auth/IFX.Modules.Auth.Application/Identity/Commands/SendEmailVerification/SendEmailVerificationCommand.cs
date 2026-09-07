using IFX.BuildingBlocks.Application.Commands;
using IFX.Modules.Auth.Application.Transactions;
using IFX.Modules.Auth.Application.Common;
using IFX.Modules.Auth.Application.Identity.DTOs;
using MediatR;

namespace IFX.Modules.Auth.Application.Identity.Commands.SendEmailVerification;

public record SendEmailVerificationCommand(
    Guid UserIdentityId,
    string? IpAddress) : ICommand<Result<EmailVerificationTokenInfo>, AuthTransactionOwner>;
