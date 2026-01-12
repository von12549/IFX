using AuthSamples.Modules.Auth.Application.Common;
using AuthSamples.Modules.Auth.Application.DTOs;
using MediatR;

namespace AuthSamples.Modules.Auth.Application.Commands.LoginUser;

public record LoginUserCommand(
    string Email,
    string Password,
    string IpAddress,
    string UserAgent) : IRequest<Result<LoginUserResponse>>;
