using IFX.BuildingBlocks.Application.Commands;
using IFX.Modules.IAM.Application.Transactions;
using IFX.Modules.IAM.Application.Common;
using IFX.Modules.IAM.Application.Identity.DTOs;
using MediatR;

namespace IFX.Modules.IAM.Application.Identity.Commands.SendEmailVerification;

public record SendEmailVerificationCommand(
    Guid UserIdentityId,
    string? IpAddress) : ICommand<Result<EmailVerificationTokenInfo>, IamTransactionOwner>;
