using IFX.BuildingBlocks.Application.Transactions;
using MediatR;

namespace IFX.BuildingBlocks.Application.Commands;

public interface ICommand<out TResponse> : IRequest<TResponse>
{
    Type TransactionOwner { get; }

    TransactionProfile TransactionProfile => TransactionProfile.DeferredWrite;
}

public interface ICommand<out TResponse, TOwner> : ICommand<TResponse>
    where TOwner : ITransactionOwner
{
    Type ICommand<TResponse>.TransactionOwner => typeof(TOwner);
}

/// <summary>
/// Marks a command whose caller may safely reconcile and retry it by a stable identity.
/// The owning module persists the identity and result in its own database transaction.
/// </summary>
public interface IIdempotentCommand<out TResponse> : ICommand<TResponse>
{
    string IdempotencyKey { get; }
}

public interface IIdempotentCommand<out TResponse, TOwner> :
    IIdempotentCommand<TResponse>,
    ICommand<TResponse, TOwner>
    where TOwner : ITransactionOwner;
