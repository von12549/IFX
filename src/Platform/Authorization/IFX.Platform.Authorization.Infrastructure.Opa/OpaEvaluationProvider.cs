using System.Net.Http.Json;
using System.Text.Json;
using IFX.Platform.Authorization.Contracts.V1;
using IFX.Platform.Authorization.Runtime;
using Microsoft.Extensions.Options;

namespace IFX.Platform.Authorization.Infrastructure.Opa;

public sealed class OpaOptions
{
    public string BaseUrl { get; set; } = "http://localhost:8181";
    public int TimeoutSeconds { get; set; } = 5;
    public bool Enabled { get; set; } = true;
    // Legacy config key remains accepted; an outage can never grant access.
    public bool FailClosed { get; set; } = true;
}

public sealed class OpaEvaluationProvider(HttpClient client, IOptions<OpaOptions> options) : IConditionEvaluationProvider
{
    public async Task<(DecisionOutcome Outcome, string ReasonCode)> EvaluateAsync(EvaluationRequest request,
        IReadOnlyList<ResolvedCondition> conditions, CancellationToken ct)
    {
        if (!options.Value.Enabled) return (DecisionOutcome.Indeterminate, "provider_disabled");
        var s = request.Subject;
        var r = request.Resource;
        var e = request.Environment;
        // Provider wire representation stays entirely inside this adapter.
        var input = new
        {
            subject = new { id = s.Id, tenant_id = s.TenantId, departments = s.Departments, roles = s.Roles,
                permissions = s.Permissions, mfa = s.Mfa, global_roles = s.GlobalRoles, is_global_admin = s.IsGlobalAdmin },
            resource = new { type = r.Type, id = r.Id, tenant_id = r.TenantId, is_active = r.IsActive,
                owner_id = r.OwnerId, departments = r.Departments },
            action = request.Action,
            environment = new { ip = e.Ip, network = e.Network, time = e.Time },
            conditions = conditions.Select(c => new { left = c.Left, @operator = Operator(c.Operator),
                right_type = c.RightType == ValueReference.Field ? "field_ref" : "literal", right = c.Right })
        };
        using var timeout = CancellationTokenSource.CreateLinkedTokenSource(ct);
        timeout.CancelAfter(TimeSpan.FromSeconds(Math.Clamp(options.Value.TimeoutSeconds, 1, 60)));
        try
        {
            using var response = await client.PostAsJsonAsync(
                options.Value.BaseUrl.TrimEnd('/') + "/v1/data/authz/common/abac_eval", new { input }, timeout.Token);
            if (!response.IsSuccessStatusCode) return (DecisionOutcome.Indeterminate, "provider_unavailable");
            using var body = JsonDocument.Parse(await response.Content.ReadAsStringAsync(timeout.Token));
            if (!body.RootElement.TryGetProperty("result", out var result) || result.ValueKind != JsonValueKind.Object ||
                !result.TryGetProperty("allow", out var allow) || allow.ValueKind is not (JsonValueKind.True or JsonValueKind.False))
                return (DecisionOutcome.Indeterminate, "invalid_provider_response");
            return allow.GetBoolean() ? (DecisionOutcome.Allow, "policy_allow") : (DecisionOutcome.Deny, "policy_deny");
        }
        catch (OperationCanceledException) when (ct.IsCancellationRequested) { throw; }
        catch (Exception) { return (DecisionOutcome.Indeterminate, "provider_unavailable"); }
    }

    private static string Operator(ConditionOperator op) => op switch
    {
        ConditionOperator.Equals => "equals", ConditionOperator.NotEquals => "not_equals",
        ConditionOperator.In => "in", ConditionOperator.NotIn => "not_in",
        ConditionOperator.Contains => "contains", ConditionOperator.Intersects => "intersects",
        _ => throw new ArgumentOutOfRangeException(nameof(op))
    };
}
