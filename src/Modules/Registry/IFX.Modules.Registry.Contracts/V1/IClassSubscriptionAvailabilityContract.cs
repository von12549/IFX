using IFX.Platform.Context.Contracts.Context;

namespace IFX.Modules.Registry.Contracts.V1;

public interface IClassSubscriptionAvailabilityContract
{
    Task<ClassSubscriptionAvailabilityResponse> CheckAsync(
        ClassSubscriptionAvailabilityRequest request,
        ContractRequestContext context,
        CancellationToken cancellationToken = default);
}

public sealed record ClassSubscriptionAvailabilityRequest(Guid ClassId, Guid TenantId);

public sealed record ClassSubscriptionAvailabilityResponse(bool IsOpen);

public sealed class ClassSubscriptionAvailabilityContractException : Exception
{
    public ClassSubscriptionAvailabilityContractException(string code)
        : base(code)
    {
        Code = code;
    }

    public string Code { get; }
}
