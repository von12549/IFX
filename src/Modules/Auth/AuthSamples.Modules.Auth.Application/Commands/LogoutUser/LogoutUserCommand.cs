using AuthSamples.Modules.Auth.Application.Common;
using MediatR;

namespace AuthSamples.Modules.Auth.Application.Commands.LogoutUser;

public record LogoutUserCommand(
    string Subject,
    string AccessToken,
    string IpAddress) : IRequest<Result<bool>>;
