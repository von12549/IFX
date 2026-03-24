using IFX.BuildingBlocks.Security.Authorization.Abac.Templates;

namespace IFX.BuildingBlocks.Security.Authorization.Abac.Registry;

/// <summary>
/// Seeds the <see cref="IAbacTemplateRegistry"/> with the standard cross-cutting templates
/// available to all modules.
/// Call <see cref="Register"/> once during DI setup.
/// </summary>
public static class BuiltInTemplates
{
    /// <summary>
    /// Allow when the subject and resource share at least one department.
    /// Left: subject.departments (collection), Right: resource.departments (collection), Operator: Intersects.
    /// </summary>
    public static readonly ConditionTemplate SameDepartment = new()
    {
        Name = "SameDepartment",
        Left = "subject.departments",
        Operator = ConditionOperator.Intersects,
        Right = ConditionValueRef.FieldRef("resource.departments")
    };

    /// <summary>
    /// Allow when the subject is the creator/owner of the resource.
    /// Left: subject.id (scalar), Right: resource.owner_id (scalar), Operator: Equals.
    /// </summary>
    public static readonly ConditionTemplate CreatedByMe = new()
    {
        Name = "CreatedByMe",
        Left = "subject.id",
        Operator = ConditionOperator.Equals,
        Right = ConditionValueRef.FieldRef("resource.owner_id")
    };

    /// <summary>
    /// Allow when the subject and resource belong to the same tenant.
    /// Left: subject.tenant_id (scalar), Right: resource.tenant_id (scalar), Operator: Equals.
    /// </summary>
    public static readonly ConditionTemplate SameTenant = new()
    {
        Name = "SameTenant",
        Left = "subject.tenant_id",
        Operator = ConditionOperator.Equals,
        Right = ConditionValueRef.FieldRef("resource.tenant_id")
    };

    /// <summary>Seeds all built-in templates into the provided registry.</summary>
    public static void Register(IAbacTemplateRegistry registry)
    {
        registry.Register(SameDepartment);
        registry.Register(CreatedByMe);
        registry.Register(SameTenant);
    }
}
