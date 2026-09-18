using Acme.Domain;

namespace Acme.Infrastructure;

public sealed class UserRepository : IUserRepository
{
    public string Find(string id) => id;
}
