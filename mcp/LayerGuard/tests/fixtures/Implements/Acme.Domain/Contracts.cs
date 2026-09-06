namespace Acme.Domain;

public interface IUserRepository
{
    string Find(string id);
}

public interface IOrderRepository<T>
{
    T Load(string id);
}
