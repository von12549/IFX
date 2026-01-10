using AuthSamples.Modules.Cognito.Application.Common;
using MediatR;

namespace AuthSamples.Modules.Cognito.Application.Commands.LogoutUser;

public record LogoutUserCommand(
    string Subject,
    string AccessToken,
    string IpAddress) : IRequest<Result<bool>>;
