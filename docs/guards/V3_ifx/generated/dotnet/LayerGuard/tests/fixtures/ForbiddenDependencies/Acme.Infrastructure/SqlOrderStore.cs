namespace Acme.Infrastructure;

/// A concrete class, declared in Infrastructure. Nothing outside may be handed one.
public sealed class SqlOrderStore
{
    public string Load(string id) => id;
}

/// Infrastructure has one of these. So does Application, under the same name.
public sealed class RetryPolicy
{
    public int Attempts => 3;
}
