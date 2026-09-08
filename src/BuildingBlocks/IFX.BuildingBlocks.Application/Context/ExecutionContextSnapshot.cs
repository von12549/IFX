using IFX.Platform.Context.Contracts;

namespace IFX.BuildingBlocks.Application.Context;

public sealed record ExecutionContextSnapshot
{
    public ExecutionContextSnapshot(
        CorrelationId correlationId,
        OperationId operationId,
        CausationId? causationId,
        ExecutionScope scope,
        ActorReference actor,
        SourceReference source,
        ContextProvenance provenance = ContextProvenance.Trusted)
    {
        if (correlationId.Value == Guid.Empty || operationId.Value == Guid.Empty)
        {
            throw new ArgumentException("CorrelationId and OperationId are required.");
        }

        if (!scope.IsTenant && !scope.IsPlatform)
        {
            throw new ArgumentException("Execution scope is required.", nameof(scope));
        }

        if (!Enum.IsDefined(provenance))
        {
            throw new ArgumentOutOfRangeException(nameof(provenance));
        }

        CorrelationId = correlationId;
        OperationId = operationId;
        CausationId = causationId;
        Scope = scope;
        Actor = actor ?? throw new ArgumentNullException(nameof(actor));
        Source = source ?? throw new ArgumentNullException(nameof(source));
        Provenance = provenance;
    }

    public CorrelationId CorrelationId { get; }
    public OperationId OperationId { get; }
    public CausationId? CausationId { get; }
    public ExecutionScope Scope { get; }
    public ActorReference Actor { get; }
    public SourceReference Source { get; }
    public ContextProvenance Provenance { get; }

    public bool IsTenantScope => Scope.IsTenant;

    public Guid? TenantId => Scope.TenantId;

    public static ExecutionContextSnapshot ForTenant(
        Guid correlationId,
        Guid operationId,
        Guid? causationId,
        Guid tenantId,
        string actorKind,
        string actorId,
        string sourceSystem,
        string sourceComponent,
        int sourceVersion) => new(
        new CorrelationId(correlationId),
        new OperationId(operationId),
        causationId is { } cause ? new CausationId(cause) : null,
        ExecutionScope.ForTenant(new TenantScope(tenantId)),
        new ActorReference(ParseActorKind(actorKind), actorId),
        new SourceReference(sourceSystem, sourceComponent, sourceVersion));

    public static ExecutionContextSnapshot ForPlatform(
        Guid correlationId,
        Guid operationId,
        Guid? causationId,
        string actorKind,
        string actorId,
        string sourceSystem,
        string sourceComponent,
        int sourceVersion) => new(
        new CorrelationId(correlationId),
        new OperationId(operationId),
        causationId is { } cause ? new CausationId(cause) : null,
        ExecutionScope.ForPlatform(new PlatformScope()),
        new ActorReference(ParseActorKind(actorKind), actorId),
        new SourceReference(sourceSystem, sourceComponent, sourceVersion));

    private static ActorKind ParseActorKind(string value) => value switch
    {
        "user" => ActorKind.User,
        "service" => ActorKind.Service,
        "system" => ActorKind.System,
        _ => throw new ArgumentException("Actor kind is not supported.", nameof(value))
    };
}
