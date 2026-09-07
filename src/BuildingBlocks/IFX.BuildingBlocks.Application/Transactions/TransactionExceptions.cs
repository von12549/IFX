namespace IFX.BuildingBlocks.Application.Transactions;

public sealed class TransactionOwnerResolutionException : InvalidOperationException
{
    public TransactionOwnerResolutionException(Type commandType, Type ownerType, int candidateCount)
        : base($"Command '{commandType.FullName}' requires exactly one transaction executor for " +
               $"owner '{ownerType.FullName}', but {candidateCount} were registered.")
    {
        CommandType = commandType;
        OwnerType = ownerType;
        CandidateCount = candidateCount;
    }

    public Type CommandType { get; }

    public Type OwnerType { get; }

    public int CandidateCount { get; }
}

public sealed class TransactionCommitOutcomeUnknownException : Exception
{
    public TransactionCommitOutcomeUnknownException(Type ownerType, Exception innerException)
        : base($"The commit outcome for transaction owner '{ownerType.FullName}' is unknown. " +
               "The operation must be reconciled by its idempotency identity before retrying.", innerException)
    {
        OwnerType = ownerType;
    }

    public Type OwnerType { get; }
}

public sealed class ConcurrencyConflictException : Exception
{
    public ConcurrencyConflictException(Type ownerType, Exception innerException)
        : base($"A concurrent update was detected for transaction owner '{ownerType.FullName}'.", innerException)
    {
        OwnerType = ownerType;
    }

    public Type OwnerType { get; }
}
