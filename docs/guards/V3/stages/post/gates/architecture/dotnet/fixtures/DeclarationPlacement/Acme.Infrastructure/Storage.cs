namespace Acme.Infrastructure;

/// The class half of the repository pair, in the ring the rules give it.
public sealed class UserRepository
{
    public string Find(string id) => id;
}

public sealed class OrderValidator
{
    public bool Validate() => true;
}
