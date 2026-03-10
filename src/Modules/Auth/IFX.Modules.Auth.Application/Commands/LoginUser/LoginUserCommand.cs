using IFX.Modules.Auth.Application.Common;
using IFX.Modules.Auth.Application.DTOs;
using MediatR;

namespace IFX.Modules.Auth.Application.Commands.LoginUser;

public record LoginUserCommand(
    string Email,
    string Password,
    string IpAddress,
    string UserAgent) : IRequest<Result<LoginUserResponse>>;
