using IFX.Modules.IAM.Application.Access.Abac.Templates;

namespace IFX.Modules.IAM.Application.Access.Abac.Registry;

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

    /// <summary>
    /// Allow only when the resource is active.
    /// Left: resource.is_active (scalar literal), Right: "true" (constant), Operator: Equals.
    /// </summary>
    public static readonly ConditionTemplate IsActive = new()
    {
        Name = "IsActive",
        Left = "resource.is_active",
        Operator = ConditionOperator.Equals,
        Right = ConditionValueRef.Literal("true")
    };

    /// <summary>
    /// Allow cross-tenant access for global-role users. Passes when the subject is a global admin.
    /// Left: subject.is_global_admin (string "true"/"false"), Right: "true" (literal), Operator: Equals.
    /// Used by platform-scope policies assigned to PlatformSupport/PlatformAuditor roles.
    /// </summary>
    public static readonly ConditionTemplate AnyTenant = new()
    {
        Name = "AnyTenant",
        Left = "subject.is_global_admin",
        Operator = ConditionOperator.Equals,
        Right = ConditionValueRef.Literal("true")
    };

    /// <summary>
    /// Allow when the subject holds a specific GlobalRole.
    /// Left: subject.global_roles (collection), Right: UserInput("role") (literal role name), Operator: Contains.
    /// The caller must supply a <c>Parameters</c> dictionary with key <c>"global_role"</c> set to the
    /// expected GlobalRole name (e.g. "PlatformSupport").
    /// </summary>
    public static readonly ConditionTemplate GlobalRoleIncludes = new()
    {
        Name = "GlobalRoleIncludes",
        Left = "subject.global_roles",
        Operator = ConditionOperator.Contains,
        Right = ConditionValueRef.UserInput("global_role")
    };

    /// <summary>Seeds all built-in templates into the provided registry.</summary>
    public static void Register(IAbacTemplateRegistry registry)
    {
        registry.Register(SameDepartment);
        registry.Register(CreatedByMe);
        registry.Register(SameTenant);
        registry.Register(IsActive);
        registry.Register(AnyTenant);
        registry.Register(GlobalRoleIncludes);
    }
}
