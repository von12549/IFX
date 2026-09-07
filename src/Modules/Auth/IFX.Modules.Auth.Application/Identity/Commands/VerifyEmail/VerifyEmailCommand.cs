using IFX.BuildingBlocks.Application.Commands;
using IFX.Modules.Auth.Application.Transactions;
using IFX.Modules.Auth.Application.Common;
using IFX.Modules.Auth.Application.Identity.DTOs;
using MediatR;

namespace IFX.Modules.Auth.Application.Identity.Commands.VerifyEmail;

public record VerifyEmailCommand(
    Guid UserIdentityId,
    string? Token,
    string? Code,
    string? IpAddress) : ICommand<Result<VerifyEmailResponse>, AuthTransactionOwner>;
