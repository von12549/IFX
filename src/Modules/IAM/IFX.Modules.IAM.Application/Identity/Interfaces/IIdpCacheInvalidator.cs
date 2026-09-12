namespace IFX.Modules.IAM.Application.Identity.Interfaces;

/// <summary>
/// Abstraction for invalidating IdP configuration cache.
/// Implemented in ApiHost to avoid circular dependencies.
/// </summary>
public interface IIdpCacheInvalidator
{
    void InvalidateCache();
}
