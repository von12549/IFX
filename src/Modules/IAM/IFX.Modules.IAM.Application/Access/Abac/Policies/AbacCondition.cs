using IFX.Modules.IAM.Application.Access.Abac.Templates;

namespace IFX.Modules.IAM.Application.Access.Abac.Policies;

/// <summary>
/// A condition template paired with optional runtime parameters.
/// The engine resolves any <see cref="ValueRefType.UserInput"/> references using
/// <see cref="Parameters"/> before sending the condition to OPA.
/// </summary>
public sealed class AbacCondition
{
    /// <summary>The reusable condition blueprint to apply.</summary>
    public ConditionTemplate Template { get; init; } = null!;

    /// <summary>
    /// Runtime values for <see cref="ValueRefType.UserInput"/> references in the template.
    /// Key = param key defined in <see cref="ConditionValueRef.Value"/>.
    /// </summary>
    public IDictionary<string, object>? Parameters { get; init; }
}
