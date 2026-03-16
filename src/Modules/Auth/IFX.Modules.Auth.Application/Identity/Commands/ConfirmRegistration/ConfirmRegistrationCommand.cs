using IFX.Modules.Auth.Application.Common;
using IFX.Modules.Auth.Application.DTOs;
using MediatR;

namespace IFX.Modules.Auth.Application.Commands.ConfirmRegistration;

public record ConfirmRegistrationCommand(
    string Email,
    string ConfirmationCode,
    string IpAddress) : IRequest<Result<ConfirmRegistrationResponse>>;
