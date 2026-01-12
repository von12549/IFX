using AuthSamples.Modules.Auth.Application.Common;
using AuthSamples.Modules.Auth.Application.DTOs;
using MediatR;

namespace AuthSamples.Modules.Auth.Application.Commands.SyncUser;

public record SyncUserCommand(string Issuer, string Subject) : IRequest<Result<UserProfileDto>>;
