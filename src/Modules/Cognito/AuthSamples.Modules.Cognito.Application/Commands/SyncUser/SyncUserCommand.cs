using AuthSamples.Modules.Cognito.Application.Common;
using AuthSamples.Modules.Cognito.Application.DTOs;
using MediatR;

namespace AuthSamples.Modules.Cognito.Application.Commands.SyncUser;

public record SyncUserCommand(string Subject) : IRequest<Result<UserProfileDto>>;
