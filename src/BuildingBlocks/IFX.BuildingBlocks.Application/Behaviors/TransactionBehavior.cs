using IFX.BuildingBlocks.Application.Commands;
using IFX.BuildingBlocks.Application.Events;
using IFX.BuildingBlocks.Application.Results;
using IFX.BuildingBlocks.Application.Transactions;
using MediatR;
using Microsoft.Extensions.Logging;

namespace IFX.BuildingBlocks.Application.Behaviors;

public sealed class TransactionBehavior<TRequest, TResponse>(
    ITransactionExecutorResolver resolver,
    ICommittedEventBuffer eventBuffer,
    ILogger<TransactionBehavior<TRequest, TResponse>> logger)
    : IPipelineBehavior<TRequest, TResponse>
    where TRequest : notnull
{
    public async Task<TResponse> Handle(
        TRequest request,
        RequestHandlerDelegate<TResponse> next,
        CancellationToken cancellationToken)
    {
        if (request is not ICommand<TResponse> command)
        {
            return await next();
        }

        var executor = resolver.Resolve(typeof(TRequest), command.TransactionOwner);
        var participants = resolver.ResolveParticipants(command.TransactionOwner);

        return command.TransactionProfile switch
        {
            TransactionProfile.DeferredWrite => await ExecuteDeferredAsync(
                request,
                executor,
                participants,
                next,
                cancellationToken),
            TransactionProfile.Inbox or TransactionProfile.ConsistentReadWrite => await ExecuteAtomicAsync(
                request,
                executor,
                participants,
                next,
                cancellationToken),
            _ => throw new ArgumentOutOfRangeException(
                nameof(command.TransactionProfile),
                command.TransactionProfile,
                "Unknown transaction profile.")
        };
    }

    private async Task<TResponse> ExecuteDeferredAsync(
        TRequest request,
        ITransactionExecutor executor,
        IReadOnlyList<ITransactionParticipant> participants,
        RequestHandlerDelegate<TResponse> next,
        CancellationToken cancellationToken)
    {
        TResponse response;
        try
        {
            response = await next();
        }
        catch
        {
            eventBuffer.Clear();
            throw;
        }

        if (!IsSuccessful(response))
        {
            await executor.DiscardChangesAsync(CancellationToken.None);
            eventBuffer.Clear();
            logger.LogInformation("Discarded changes for failed command {RequestName}", typeof(TRequest).Name);
            return response;
        }

        try
        {
            await executor.ExecutePersistenceAsync(
                token => PrepareParticipantsAsync(participants, request, response, token),
                cancellationToken);
        }
        catch
        {
            eventBuffer.Clear();
            throw;
        }

        await eventBuffer.DispatchAfterCommitAsync(cancellationToken);
        return response;
    }

    private async Task<TResponse> ExecuteAtomicAsync(
        TRequest request,
        ITransactionExecutor executor,
        IReadOnlyList<ITransactionParticipant> participants,
        RequestHandlerDelegate<TResponse> next,
        CancellationToken cancellationToken)
    {
        TResponse? response = default;
        var rejected = false;

        try
        {
            await executor.ExecuteAtomicAsync(
                async token =>
                {
                    response = await next();
                    if (!IsSuccessful(response))
                    {
                        rejected = true;
                        throw TransactionRejectedSignal.Instance;
                    }

                    await PrepareParticipantsAsync(participants, request, response, token);
                },
                cancellationToken);
        }
        catch (TransactionRejectedSignal) when (rejected)
        {
            // A normal business rejection controls rollback but remains a result, not an exception.
        }
        catch
        {
            eventBuffer.Clear();
            throw;
        }

        if (rejected)
        {
            await executor.DiscardChangesAsync(CancellationToken.None);
            eventBuffer.Clear();
        }
        else
        {
            await eventBuffer.DispatchAfterCommitAsync(cancellationToken);
        }

        return response!;
    }

    private static bool IsSuccessful(TResponse response)
    {
        if (response is not IOperationResult result)
        {
            throw new InvalidOperationException(
                $"Command response '{typeof(TResponse).FullName}' must implement {nameof(IOperationResult)}.");
        }

        return result.IsSuccess;
    }

    private static async Task PrepareParticipantsAsync(
        IReadOnlyList<ITransactionParticipant> participants,
        TRequest request,
        TResponse response,
        CancellationToken cancellationToken)
    {
        foreach (var participant in participants)
        {
            await participant.PrepareAsync(request, response, cancellationToken);
        }
    }

    private sealed class TransactionRejectedSignal : Exception
    {
        public static TransactionRejectedSignal Instance { get; } = new();

        private TransactionRejectedSignal()
        {
        }
    }
}
