namespace IFX.BuildingBlocks.Security.Authorization.Abac.Templates;

/// <summary>
/// Describes the right-hand side of a condition — what value to compare against.
/// </summary>
public sealed class ConditionValueRef
{
    /// <summary>How the value is resolved at evaluation time.</summary>
    public ValueRefType Type { get; init; }

    /// <summary>
    /// The value payload:
    /// <list type="bullet">
    ///   <item><description><see cref="ValueRefType.Literal"/> — the literal value itself.</description></item>
    ///   <item><description><see cref="ValueRefType.FieldRef"/> — dot-path into OPA input (e.g. "resource.owner_id").</description></item>
    ///   <item><description><see cref="ValueRefType.UserInput"/> — key in the caller-supplied parameters dictionary.</description></item>
    /// </list>
    /// </summary>
    public string Value { get; init; } = string.Empty;

    public static ConditionValueRef Literal(string value) =>
        new() { Type = ValueRefType.Literal, Value = value };

    public static ConditionValueRef FieldRef(string path) =>
        new() { Type = ValueRefType.FieldRef, Value = path };

    public static ConditionValueRef UserInput(string paramKey) =>
        new() { Type = ValueRefType.UserInput, Value = paramKey };
}
