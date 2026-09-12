using IFX.BuildingBlocks.Security.Authorization.Exceptions;

namespace IFX.Modules.IAM.Application.Access.Abac.Resolver;

public enum PolicyFailure { Disabled, Invalid, Unavailable }
public sealed class PolicyResolutionException(PolicyFailure failure) : ForbiddenException("policy_" + failure.ToString().ToLowerInvariant())
{
    public PolicyFailure Failure { get; } = failure;
}
