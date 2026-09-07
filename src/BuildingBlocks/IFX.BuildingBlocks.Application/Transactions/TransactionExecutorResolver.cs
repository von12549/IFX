using Microsoft.Extensions.DependencyInjection;

namespace IFX.BuildingBlocks.Application.Transactions;

public interface ITransactionExecutorResolver
{
    ITransactionExecutor Resolve(Type commandType, Type ownerType);

    IReadOnlyList<ITransactionParticipant> ResolveParticipants(Type ownerType);
}

internal sealed class TransactionExecutorResolver(IServiceProvider serviceProvider) : ITransactionExecutorResolver
{
    public ITransactionExecutor Resolve(Type commandType, Type ownerType)
    {
        var candidates = serviceProvider.GetKeyedServices<ITransactionExecutor>(ownerType).ToArray();
        if (candidates.Length != 1)
        {
            throw new TransactionOwnerResolutionException(commandType, ownerType, candidates.Length);
        }

        return candidates[0];
    }

    public IReadOnlyList<ITransactionParticipant> ResolveParticipants(Type ownerType) =>
        serviceProvider.GetKeyedServices<ITransactionParticipant>(ownerType).ToArray();
}
