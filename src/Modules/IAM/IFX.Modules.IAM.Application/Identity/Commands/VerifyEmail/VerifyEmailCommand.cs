using IFX.BuildingBlocks.Application.Commands;
using IFX.Modules.IAM.Application.Transactions;
using IFX.Modules.IAM.Application.Common;
using IFX.Modules.IAM.Application.Identity.DTOs;
using MediatR;

namespace IFX.Modules.IAM.Application.Identity.Commands.VerifyEmail;

public record VerifyEmailCommand(
    Guid UserIdentityId,
    string? Token,
    string? Code,
    string? IpAddress) : ICommand<Result<VerifyEmailResponse>, AuthTransactionOwner>;
