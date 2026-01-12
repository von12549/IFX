using AuthSamples.Modules.Auth.Application.Common;
using AuthSamples.Modules.Auth.Application.DTOs;
using MediatR;

namespace AuthSamples.Modules.Auth.Application.Commands.ConfirmRegistration;

public record ConfirmRegistrationCommand(
    string Email,
    string ConfirmationCode,
    string IpAddress) : IRequest<Result<ConfirmRegistrationResponse>>;
