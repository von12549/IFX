namespace Acme.Infrastructure;

public interface ICacheRepository
{
    string Find(string id);
}

public sealed class CacheRepository : ICacheRepository
{
    public string Find(string id) => id;
}
