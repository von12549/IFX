using IFX.Platform.Authorization.Contracts.V1;

namespace IFX.Platform.Authorization.Runtime;

// Provider input after parameter substitution; it is not a policy-selection service.
public sealed record ResolvedCondition(string Left, ConditionOperator Operator, ValueReference RightType, string Right);
public interface IConditionEvaluationProvider
{
    Task<(DecisionOutcome Outcome, string ReasonCode)> EvaluateAsync(EvaluationRequest request,
        IReadOnlyList<ResolvedCondition> conditions, CancellationToken ct);
}

public sealed class ConditionParameterResolver
{
    private static readonly HashSet<string> Fields = new(StringComparer.Ordinal)
    {
        "subject.id", "subject.tenant_id", "subject.departments", "subject.roles", "subject.permissions",
        "subject.mfa", "subject.global_roles", "subject.is_global_admin", "resource.type", "resource.id",
        "resource.tenant_id", "resource.is_active", "resource.owner_id", "resource.departments",
        "environment.ip", "environment.network", "environment.time", "action"
    };

    public IReadOnlyList<ResolvedCondition> Resolve(PolicySnapshot policy)
    {
        if (string.IsNullOrWhiteSpace(policy.Version) || policy.Conditions.Count is 0 or > 100)
            throw new ArgumentException("Invalid policy snapshot.");
        return policy.Conditions.Select(c =>
        {
            if (!Fields.Contains(c.Left) || !Enum.IsDefined(c.Operator) || !Enum.IsDefined(c.RightType) ||
                c.RightType == ValueReference.Field && !Fields.Contains(c.Right) ||
                c.RightType == ValueReference.Parameter && c.ParameterValue is null)
                throw new ArgumentException("Invalid condition or missing parameter.");
            return new ResolvedCondition(c.Left, c.Operator,
                c.RightType == ValueReference.Parameter ? ValueReference.Literal : c.RightType,
                c.RightType == ValueReference.Parameter ? c.ParameterValue! : c.Right);
        }).ToArray();
    }
}

public sealed class AuthorizationRuntime(IConditionEvaluationProvider provider) : IAuthorizationEvaluationContract
{
    public async Task<EvaluationResponse> EvaluateAsync(EvaluationRequest request, CancellationToken ct = default)
    {
        ct.ThrowIfCancellationRequested();
        var id = Guid.NewGuid();
        try
        {
            if (string.IsNullOrWhiteSpace(request.Subject.Id) || string.IsNullOrWhiteSpace(request.Resource.Type) ||
                string.IsNullOrWhiteSpace(request.Action))
                return new(DecisionOutcome.Indeterminate, "invalid_input", id, request.Policy.Version);
            var conditions = new ConditionParameterResolver().Resolve(request.Policy);
            var result = await provider.EvaluateAsync(request, conditions, ct);
            return new(result.Outcome, result.ReasonCode, id, request.Policy.Version);
        }
        catch (ArgumentException) { return new(DecisionOutcome.Indeterminate, "invalid_policy", id, request.Policy.Version); }
        catch (OperationCanceledException) when (ct.IsCancellationRequested) { throw; }
        catch (Exception) { return new(DecisionOutcome.Indeterminate, "evaluation_unavailable", id, request.Policy.Version); }
    }
}
