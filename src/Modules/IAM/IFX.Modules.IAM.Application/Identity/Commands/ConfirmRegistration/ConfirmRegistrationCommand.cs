using IFX.BuildingBlocks.Application.Commands;
using IFX.Modules.IAM.Application.Transactions;
using IFX.Modules.IAM.Application.Common;
using IFX.Modules.IAM.Application.Identity.DTOs;
using MediatR;

namespace IFX.Modules.IAM.Application.Identity.Commands.ConfirmRegistration;

public record ConfirmRegistrationCommand(
    string Email,
    string ConfirmationCode,
    string IpAddress) : ICommand<Result<ConfirmRegistrationResponse>, AuthTransactionOwner>;
