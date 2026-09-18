namespace Acme.Infrastructure;

public interface ITracked
{
    void Touch();
}

/// Names the contract in full and closes its type argument. Both are the same contract as the
/// one Domain declares, and neither is resolved by a compiler.
public sealed class OrderRepository : ITracked, Acme.Domain.IOrderRepository<string>
{
    public void Touch() { }

    public string Load(string id) => id;
}
