using IFX.Modules.Auth.Application.Common;
using MediatR;

namespace IFX.Modules.Auth.Application.Authorization.Policies.Commands.DeletePolicy;

public record DeletePolicyCommand(Guid PolicyId) : IRequest<Result<bool>>;
