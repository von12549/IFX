namespace IFX.Platform.Context.Runtime.Inbound;

public enum ContractTenantValidation
{
    None = 0,
    RequireTenantResource = 1,
    MatchWhenTenantScoped = 2
}

public sealed class InboundContractPolicy
{
    private readonly HashSet<ContractComponentIdentity> _allowedConsumers;
    private readonly HashSet<string> _allowedActorKinds;

    public InboundContractPolicy(
        IEnumerable<ContractComponentIdentity> allowedConsumers,
        IEnumerable<string> allowedActorKinds,
        bool allowTenantScope,
        bool allowPlatformScope,
        ContractTenantValidation tenantValidation)
    {
        ArgumentNullException.ThrowIfNull(allowedConsumers);
        ArgumentNullException.ThrowIfNull(allowedActorKinds);

        _allowedConsumers = allowedConsumers.ToHashSet();
        _allowedActorKinds = allowedActorKinds.ToHashSet(StringComparer.Ordinal);
        if (_allowedConsumers.Count == 0)
        {
            throw new ArgumentException("At least one contract consumer is required.", nameof(allowedConsumers));
        }

        if (_allowedActorKinds.Count == 0 || _allowedActorKinds.Any(kind => kind is not ("user" or "service" or "system")))
        {
            throw new ArgumentException("At least one supported actor kind is required.", nameof(allowedActorKinds));
        }

        if (!allowTenantScope && !allowPlatformScope)
        {
            throw new ArgumentException("At least one execution scope must be allowed.");
        }

        if (tenantValidation == ContractTenantValidation.RequireTenantResource && !allowTenantScope)
        {
            throw new ArgumentException("Tenant resource validation requires tenant scope support.", nameof(tenantValidation));
        }

        AllowTenantScope = allowTenantScope;
        AllowPlatformScope = allowPlatformScope;
        TenantValidation = tenantValidation;
    }

    public bool AllowTenantScope { get; }

    public bool AllowPlatformScope { get; }

    public ContractTenantValidation TenantValidation { get; }

    internal bool AllowsConsumer(ContractComponentIdentity consumer) => _allowedConsumers.Contains(consumer);

    internal bool AllowsActor(string actorKind) => _allowedActorKinds.Contains(actorKind);
}
