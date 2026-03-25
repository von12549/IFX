namespace IFX.BuildingBlocks.Security.Authorization.Abac.Resolver;

/// <summary>
/// Allows command handlers (Application layer) to invalidate cached ABAC policies
/// after create/update/delete operations, without depending on the Infrastructure implementation.
/// </summary>
public interface IAbacPolicyCache
{
    void Invalidate(Guid tenantId, string resourceType, string action);
    void InvalidatePlatform(string resourceType, string action);
}
