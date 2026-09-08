namespace IFX.Platform.Context.Contracts.Context;

public sealed record ContractRequestContext
{
    public const int CurrentVersion = 1;
    public const string TenantScope = "tenant";
    public const string PlatformScope = "platform";
    public const string TrustedProvenance = "trusted";
    public const string SynthesizedProvenance = "synthesized";

    public ContractRequestContext(
        Guid requestId,
        Guid correlationId,
        Guid? causationId,
        string scope,
        Guid? tenantId,
        string actorKind,
        string actorId,
        string sourceSystem,
        string sourceComponent,
        int sourceVersion,
        string provenance = TrustedProvenance,
        int version = CurrentVersion)
    {
        RequestId = RequireIdentifier(requestId, nameof(requestId));
        CorrelationId = RequireIdentifier(correlationId, nameof(correlationId));
        if (causationId == Guid.Empty)
        {
            throw new ArgumentException("CausationId cannot be empty when supplied.", nameof(causationId));
        }

        if (scope == TenantScope)
        {
            TenantId = tenantId is { } value && value != Guid.Empty
                ? value
                : throw new ArgumentException("Tenant scope requires a non-empty TenantId.", nameof(tenantId));
        }
        else if (scope == PlatformScope)
        {
            if (tenantId is not null)
            {
                throw new ArgumentException("Platform scope cannot carry a TenantId.", nameof(tenantId));
            }
        }
        else
        {
            throw new ArgumentException("Scope must be tenant or platform.", nameof(scope));
        }

        if (actorKind is not ("user" or "service" or "system"))
        {
            throw new ArgumentException("ActorKind is not supported.", nameof(actorKind));
        }

        if (provenance is not (TrustedProvenance or SynthesizedProvenance))
        {
            throw new ArgumentException("Context provenance is not supported.", nameof(provenance));
        }

        if (version != CurrentVersion || sourceVersion <= 0)
        {
            throw new ArgumentOutOfRangeException(nameof(version), "Context and source versions must be supported positive values.");
        }

        CausationId = causationId;
        Scope = scope;
        ActorKind = actorKind;
        ActorId = RequireText(actorId, nameof(actorId), 128);
        SourceSystem = RequireIdentity(sourceSystem, nameof(sourceSystem));
        SourceComponent = RequireIdentity(sourceComponent, nameof(sourceComponent));
        SourceVersion = sourceVersion;
        Provenance = provenance;
        Version = version;
    }

    public int Version { get; }
    public Guid RequestId { get; }
    public Guid CorrelationId { get; }
    public Guid? CausationId { get; }
    public string Scope { get; }
    public Guid? TenantId { get; }
    public string ActorKind { get; }
    public string ActorId { get; }
    public string SourceSystem { get; }
    public string SourceComponent { get; }
    public int SourceVersion { get; }
    public string Provenance { get; }

    private static Guid RequireIdentifier(Guid value, string parameterName) => value == Guid.Empty
        ? throw new ArgumentException("Protocol identifier cannot be empty.", parameterName)
        : value;

    private static string RequireText(string value, string parameterName, int maximumLength) =>
        string.IsNullOrWhiteSpace(value) || value.Length > maximumLength || value.Any(char.IsControl)
            ? throw new ArgumentException("Protocol value is missing or invalid.", parameterName)
            : value;

    private static string RequireIdentity(string value, string parameterName)
    {
        if (string.IsNullOrWhiteSpace(value) || value.Length > 128 || value.Any(character =>
                !char.IsAsciiLetterOrDigit(character) && character is not ('.' or '-')) || value.Any(char.IsUpper))
        {
            throw new ArgumentException("Protocol identity must use lowercase letters, digits, dots or hyphens.", parameterName);
        }

        return value;
    }
}
