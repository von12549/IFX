using IFX.Modules.IAM.Application.Access.Abac.Templates;

namespace IFX.Modules.IAM.Application.Access.Abac.Registry;

/// <summary>
/// Registry of named <see cref="ConditionTemplate"/>s.
/// Register as a singleton. Modules register their own templates at DI startup via
/// <see cref="Register"/>.
/// </summary>
public interface IAbacTemplateRegistry
{
    /// <summary>Register a template. Overwrites any existing entry with the same name.</summary>
    void Register(ConditionTemplate template);

    /// <summary>
    /// Retrieve a template by name.
    /// Throws <see cref="InvalidOperationException"/> if not found — fail-fast.
    /// </summary>
    ConditionTemplate Resolve(string templateName);

    /// <summary>Try to retrieve a template by name without throwing.</summary>
    bool TryResolve(string templateName, out ConditionTemplate? template);

    /// <summary>Returns all registered templates.</summary>
    IReadOnlyCollection<ConditionTemplate> GetAll();
}
