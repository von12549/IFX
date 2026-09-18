namespace Acme.Application;

/// Application is not named in forbiddenDependencies, so the pattern rule leaves it alone.
public sealed class CreateOrderHandler(IOrderRepository orders)
{
    public string Handle() => orders.ToString() ?? "";
}

/// Handed a concrete class from Infrastructure. No naming convention says SqlOrderStore is one
/// — only the ring that declares it does.
public sealed class ArchiveOrderHandler(SqlOrderStore store)
{
    public string Handle() => store.Load("1");
}

/// Application declares its own RetryPolicy, so the name below binds at home and nothing is
/// reported. Names are matched here, never resolved.
public sealed class RetryPolicy
{
    public int Attempts => 1;
}

public sealed class ReplayOrderHandler(RetryPolicy policy)
{
    public int Handle() => policy.Attempts;
}
