namespace IFX.Modules.IAM.Domain.Access;

/// <summary>
/// Value object stored as JSON in <see cref="PolicyDefinition.ConditionsJson"/>.
/// Each record maps to a registered <see cref="IFX.BuildingBlocks.Security.Authorization.Abac.Templates.ConditionTemplate"/>
/// by name.
/// </summary>
public sealed record PolicyConditionRecord(
    string TemplateName,
    Dictionary<string, object>? Parameters);
