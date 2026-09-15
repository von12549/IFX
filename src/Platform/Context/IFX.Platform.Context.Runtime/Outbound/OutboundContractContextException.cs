namespace IFX.Platform.Context.Runtime.Outbound;

public enum OutboundContractContextFailure
{
    ContextInvalid = 1,
    TenantMismatch = 2
}

public sealed class OutboundContractContextException(OutboundContractContextFailure failure)
    : Exception(failure == OutboundContractContextFailure.TenantMismatch
        ? "contract_tenant_mismatch"
        : "contract_context_invalid")
{
    public OutboundContractContextFailure Failure { get; } = failure;
}
