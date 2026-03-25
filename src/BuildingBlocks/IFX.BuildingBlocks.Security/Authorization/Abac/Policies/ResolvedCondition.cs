using System.Text.Json.Serialization;

namespace IFX.BuildingBlocks.Security.Authorization.Abac.Policies;

/// <summary>
/// A fully resolved condition ready to be serialized into the OPA input envelope.
/// All <see cref="Templates.ValueRefType.UserInput"/> references have been substituted.
/// Only <c>literal</c> and <c>field_ref</c> right-hand types appear here.
/// </summary>
public sealed class ResolvedCondition
{
    /// <summary>Dot-path into the OPA input for the left-hand side (e.g. "subject.departments").</summary>
    [JsonPropertyName("left")]
    public string Left { get; init; } = string.Empty;

    /// <summary>Snake-case operator string evaluated by the Rego policy (e.g. "intersects").</summary>
    [JsonPropertyName("operator")]
    public string Operator { get; init; } = string.Empty;

    /// <summary>"literal" or "field_ref" — tells the Rego evaluator how to resolve <see cref="Right"/>.</summary>
    [JsonPropertyName("right_type")]
    public string RightType { get; init; } = string.Empty;

    /// <summary>The right-hand value: a literal string or a dot-path into OPA input.</summary>
    [JsonPropertyName("right")]
    public string Right { get; init; } = string.Empty;
}
