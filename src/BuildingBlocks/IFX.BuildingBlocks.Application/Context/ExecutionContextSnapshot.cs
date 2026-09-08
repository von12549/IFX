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
}
