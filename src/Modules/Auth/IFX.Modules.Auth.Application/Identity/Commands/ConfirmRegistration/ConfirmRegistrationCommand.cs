using IFX.Modules.Auth.Application.Common;
using IFX.Modules.Auth.Application.Identity.DTOs;
using MediatR;

namespace IFX.Modules.Auth.Application.Identity.Commands.ConfirmRegistration;

public record ConfirmRegistrationCommand(
    string Email,
    string ConfirmationCode,
    string IpAddress) : IRequest<Result<ConfirmRegistrationResponse>>;
