namespace IFX.BuildingBlocks.Application.Transactions;

public enum TransactionProfile
{
    DeferredWrite = 0,
    Inbox = 1,
    ConsistentReadWrite = 2
}

public interface ITransactionOwner;
