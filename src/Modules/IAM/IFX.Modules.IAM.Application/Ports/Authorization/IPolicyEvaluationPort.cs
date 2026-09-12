using IFX.Modules.IAM.Application.Access.Abac.Policies;

namespace IFX.Modules.IAM.Application.Ports.Authorization;

public sealed record SubjectFacts(string Id, string? TenantId, IReadOnlyCollection<string> Departments,
    IReadOnlyCollection<string> Roles, IReadOnlyCollection<string> Permissions, bool Mfa,
    IReadOnlyList<string> GlobalRoles, string IsGlobalAdmin);
public sealed record EnvironmentFacts(string? Ip, string? Network, string Time);
public interface IAuthorizationEnvironmentPort { EnvironmentFacts GetFacts(); }
public interface IPolicyEvaluationPort
{
    Task<bool> EvaluateAsync(SubjectFacts subject, ResourceAttributes resource, AbacPolicy policy,
        EnvironmentFacts environment, IDictionary<string, object>? parameters, CancellationToken ct);
}
