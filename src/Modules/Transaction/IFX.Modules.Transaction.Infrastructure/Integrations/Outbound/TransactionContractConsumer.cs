using IFX.Platform.Context.Runtime;

namespace IFX.Modules.Transaction.Infrastructure.Integrations.Outbound;

internal static class TransactionContractConsumer
{
    public static ContractComponentIdentity Identity { get; } = new("ifx", "transaction", 1);
}
