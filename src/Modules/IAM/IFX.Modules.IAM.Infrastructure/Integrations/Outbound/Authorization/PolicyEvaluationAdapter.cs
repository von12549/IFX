using System.Globalization;
using System.Security.Cryptography;
using System.Text.Json;
using IFX.Modules.IAM.Application.Access.Abac.Policies;
using IFX.Modules.IAM.Application.Ports.Authorization;
using Contract = IFX.Platform.Authorization.Contracts.V1;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.IAM.Infrastructure.Integrations.Outbound.Authorization;

public sealed class PolicyEvaluationAdapter(Contract.IAuthorizationEvaluationContract evaluation, ILogger<PolicyEvaluationAdapter> logger) : IPolicyEvaluationPort
{
    public async Task<bool> EvaluateAsync(SubjectFacts subject, ResourceAttributes resource, AbacPolicy policy,
        EnvironmentFacts environment, IDictionary<string, object>? parameters, CancellationToken ct)
    {
        var conditions = policy.Conditions.Select(c =>
        {
            var t = c.Template;
            var values = c.Parameters ?? parameters;
            string? parameter = null;
            if (values is not null && values.TryGetValue(t.Right.Value, out var value))
                parameter = Convert.ToString(value, CultureInfo.InvariantCulture) ?? string.Empty;
            return new Contract.ConditionSpec(t.Left, (Contract.ConditionOperator)(int)t.Operator,
                (Contract.ValueReference)(int)t.Right.Type, t.Right.Value, parameter);
        }).ToArray();
        var version = Convert.ToHexString(SHA256.HashData(JsonSerializer.SerializeToUtf8Bytes(
            new { SchemaVersion = 2, policy.Version, policy.Classification, policy.ResourceType, policy.Action, Conditions = conditions })));
        var result = await evaluation.EvaluateAsync(new(
            new(subject.Id, subject.TenantId, subject.Departments, subject.Roles, subject.Permissions, subject.Mfa,
                subject.GlobalRoles, subject.IsGlobalAdmin),
            new(resource.Type, resource.Id, resource.TenantId, resource.IsActive, resource.OwnerId, resource.Departments),
            policy.Action, new(environment.Ip, environment.Network, environment.Time), new(version, conditions)), ct);
        logger.LogInformation("Authorization decision {Outcome} {ReasonCode} {DecisionId} {PolicyVersion}",
            result.Outcome, result.ReasonCode, result.DecisionId, result.PolicyVersion);
        return result.Outcome == Contract.DecisionOutcome.Allow;
    }
}
