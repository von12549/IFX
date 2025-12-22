using AuthSamples.Modules.Cognito.Application.Common;
using AuthSamples.Modules.Cognito.Application.DTOs;
using MediatR;

namespace AuthSamples.Modules.Cognito.Application.Commands.LoginUser;

public record LoginUserCommand(
    string Email,
    string Password,
    string IpAddress,
    string UserAgent) : IRequest<Result<LoginUserResponse>>;
