using System.Collections.Concurrent;
using IFX.BuildingBlocks.Security.Authorization.Abac.Templates;

namespace IFX.BuildingBlocks.Security.Authorization.Abac.Registry;

/// <summary>
/// Thread-safe in-memory implementation of <see cref="IAbacTemplateRegistry"/>.
/// Register as singleton. Call <see cref="BuiltInTemplates.Register"/> after construction
/// to seed the well-known templates.
/// </summary>
public sealed class AbacTemplateRegistry : IAbacTemplateRegistry
{
    private readonly ConcurrentDictionary<string, ConditionTemplate> _templates = new(StringComparer.OrdinalIgnoreCase);

    public void Register(ConditionTemplate template)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(template.Name);
        _templates[template.Name] = template;
    }

    public ConditionTemplate Resolve(string templateName)
    {
        if (_templates.TryGetValue(templateName, out var template))
            return template;

        throw new InvalidOperationException(
            $"ABAC template '{templateName}' is not registered. " +
            $"Call IAbacTemplateRegistry.Register() at startup.");
    }

    public bool TryResolve(string templateName, out ConditionTemplate? template) =>
        _templates.TryGetValue(templateName, out template);
}
