namespace Acme.Presentation;

/// A contract declared where the callers are, instead of where the rule puts it.
public interface IOrderRepository
{
    string Find(string id);
}

public sealed class DeleteOrderQueryHandler
{
    public string Handle() => "";
}
