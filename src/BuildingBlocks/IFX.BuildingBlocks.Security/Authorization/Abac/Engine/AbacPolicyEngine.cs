using IFX.BuildingBlocks.Security.Authorization.Abac.Policies;
using IFX.BuildingBlocks.Security.Authorization.Abac.Templates;

namespace IFX.BuildingBlocks.Security.Authorization.Abac.Engine;

/// <summary>
/// Default implementation of <see cref="IAbacPolicyEngine"/>.
/// Resolves <see cref="Templates.ValueRefType.UserInput"/> references from a caller-supplied
/// parameters dictionary and converts each <see cref="AbacCondition"/> into a
/// <see cref="ResolvedCondition"/> that can be serialized into the OPA input envelope.
/// </summary>
public sealed class AbacPolicyEngine : IAbacPolicyEngine
{
    public IReadOnlyList<ResolvedCondition> Resolve(
        AbacPolicy policy,
        IDictionary<string, object>? parameters = null)
    {
        var resolved = new List<ResolvedCondition>(policy.Conditions.Count);

        foreach (var condition in policy.Conditions)
        {
            var template = condition.Template;
            var (rightType, rightValue) = ResolveRight(template, condition.Parameters ?? parameters);

            resolved.Add(new ResolvedCondition
            {
                Left = template.Left,
                Operator = ToSnakeCase(template.Operator),
                RightType = rightType,
                Right = rightValue
            });
        }

        return resolved;
    }

    private static (string rightType, string rightValue) ResolveRight(
        ConditionTemplate template,
        IDictionary<string, object>? parameters)
    {
        var right = template.Right;

        return right.Type switch
        {
            ValueRefType.Literal  => ("literal",   right.Value),
            ValueRefType.FieldRef => ("field_ref", right.Value),
            ValueRefType.UserInput => ResolveUserInput(template.Name, right.Value, parameters),
            _ => throw new ArgumentOutOfRangeException(nameof(template), right.Type, "Unknown ValueRefType.")
        };
    }

    private static (string rightType, string rightValue) ResolveUserInput(
        string templateName,
        string paramKey,
        IDictionary<string, object>? parameters)
    {
        if (parameters is null || !parameters.TryGetValue(paramKey, out var value))
            throw new ArgumentException(
                $"Template '{templateName}' requires UserInput parameter '{paramKey}', " +
                $"but it was not supplied in the parameters dictionary.");

        return ("literal", value?.ToString() ?? string.Empty);
    }

    private static string ToSnakeCase(ConditionOperator op) => op switch
    {
        ConditionOperator.Equals     => "equals",
        ConditionOperator.NotEquals  => "not_equals",
        ConditionOperator.In         => "in",
        ConditionOperator.NotIn      => "not_in",
        ConditionOperator.Contains   => "contains",
        ConditionOperator.Intersects => "intersects",
        _ => throw new ArgumentOutOfRangeException(nameof(op), op, "Unknown ConditionOperator.")
    };
}
