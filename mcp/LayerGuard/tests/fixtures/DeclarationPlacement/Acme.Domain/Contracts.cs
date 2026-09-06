namespace Acme.Domain;

/// Where a repository interface belongs. `*Repository` also matches this name, and that rule
/// sends classes to Infrastructure — only the kind filter keeps this one out of it.
public interface IUserRepository
{
    string Find(string id);
}

/// A handler that never left the ring it was written in.
public sealed class CreateUserCommandHandler
{
    public string Handle() => "";
}
