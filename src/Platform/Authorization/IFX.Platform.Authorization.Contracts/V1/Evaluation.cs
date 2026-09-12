namespace IFX.Platform.Authorization.Contracts.V1;

public enum DecisionOutcome { Allow, Deny, Indeterminate }
public enum ConditionOperator { Equals, NotEquals, In, NotIn, Contains, Intersects }
public enum ValueReference { Literal, Field, Parameter }
public sealed record ConditionSpec(string Left, ConditionOperator Operator, ValueReference RightType, string Right, string? ParameterValue = null);
public sealed record PolicySnapshot(string Version, IReadOnlyList<ConditionSpec> Conditions);
public sealed record SubjectFacts(string Id, string? TenantId, IReadOnlyCollection<string> Departments,
    IReadOnlyCollection<string> Roles, IReadOnlyCollection<string> Permissions, bool Mfa,
    IReadOnlyList<string> GlobalRoles, string IsGlobalAdmin);
public sealed record ResourceFacts(string Type, string Id, string TenantId, string IsActive,
    string? OwnerId = null, IReadOnlyCollection<string>? Departments = null);
public sealed record EnvironmentFacts(string? Ip, string? Network, string Time);
public sealed record EvaluationRequest(SubjectFacts Subject, ResourceFacts Resource, string Action,
    EnvironmentFacts Environment, PolicySnapshot Policy);
public sealed record EvaluationResponse(DecisionOutcome Outcome, string ReasonCode, Guid DecisionId, string PolicyVersion);
