namespace Acme.Presentation;

/// Asks a use case for the answer. Nothing here is a repository.
public sealed class OrderEndpoints(ISender sender)
{
    public string Handle() => sender.ToString() ?? "";
}

/// A primary constructor is a statement about what the type holds.
public sealed class UserEndpoints(IUserRepository users)
{
    public string Handle() => users.ToString() ?? "";
}

/// A declared constructor says the same thing, and has to be read too.
public sealed class AuditEndpoints
{
    private readonly IAuditRepository audit;

    public AuditEndpoints(IAuditRepository audit) => this.audit = audit;

    public string Handle() => audit.ToString() ?? "";
}

/// Wrapping the dependency does not stop it being one.
public sealed class ReportEndpoints(IReadOnlyList<IOrderRepository> orders)
{
    public int Count() => orders.Count;
}

/// A nullable one is still one.
public sealed class SearchEndpoints(ISearchRepository? search)
{
    public string Handle() => search?.ToString() ?? "";
}

/// A static class has no constructor to inject into: what it is handed arrives on the method.
public static class TenantEndpoints
{
    public static string Handle(ISender sender, ITenantRepository tenants) =>
        sender.ToString() + tenants.ToString();
}
