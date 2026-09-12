namespace IFX.Modules.IAM.Application.Access.Abac.Templates;

public enum ValueRefType
{
    /// <summary>A fixed value baked into the template definition.</summary>
    Literal,

    /// <summary>A dot-path into the OPA input (e.g. "subject.id", "resource.tenant_id").</summary>
    FieldRef,

    /// <summary>Resolved from the caller-supplied parameters dictionary at runtime.</summary>
    UserInput
}
