namespace IFX.BuildingBlocks.Security.Authorization.Abac.Templates;

/// <summary>
/// A named, reusable condition blueprint.
/// Registered in <see cref="IFX.BuildingBlocks.Security.Authorization.Abac.Registry.IAbacTemplateRegistry"/>.
/// </summary>
public sealed class ConditionTemplate
{
    /// <summary>Unique name used to look up this template (e.g. "SameDepartment").</summary>
    public string Name { get; init; } = string.Empty;

    /// <summary>Dot-path into the OPA input for the left-hand side (e.g. "subject.departments").</summary>
    public string Left { get; init; } = string.Empty;

    /// <summary>Comparison operator applied between Left and Right.</summary>
    public ConditionOperator Operator { get; init; }

    /// <summary>Right-hand side value descriptor.</summary>
    public ConditionValueRef Right { get; init; } = null!;
}
