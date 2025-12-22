using AuthSamples.Modules.Cognito.Application.Common;
using AuthSamples.Modules.Cognito.Application.DTOs;
using MediatR;

namespace AuthSamples.Modules.Cognito.Application.Commands.ConfirmRegistration;

public record ConfirmRegistrationCommand(
    string Email,
    string ConfirmationCode,
    string IpAddress) : IRequest<Result<ConfirmRegistrationResponse>>;
