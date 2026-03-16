using IFX.Modules.Auth.Application.Common;
using IFX.Modules.Auth.Application.DTOs;
using MediatR;

namespace IFX.Modules.Auth.Application.Commands.SyncUser;

public record SyncUserCommand(string Issuer, string Subject) : IRequest<Result<UserProfileDto>>;
