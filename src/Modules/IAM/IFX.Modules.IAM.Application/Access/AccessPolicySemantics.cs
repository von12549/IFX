namespace IFX.Modules.IAM.Application.Access;

/// <summary>Versioned IAM rules. These are mandatory constraints, not tenant-editable policy templates.</summary>
public static class AccessPolicySemantics
{
    public const int Version = 2;
    private static readonly HashSet<string> Resources = new(StringComparer.Ordinal)
    {
        "user", "role", "rolegroup", "permission", "policy", "platform_policy", "tenant", "department", "idp",
        "party", "investor", "investment-account", "product", "fund", "fundclass", "holding", "order", "transaction"
    };
    private static readonly HashSet<string> Actions = new(StringComparer.Ordinal)
    { "list", "read", "read_admin", "create", "update", "delete", "manage", "process", "cancel" };

    public static bool IsKnownOperation(string resource, string action) => Resources.Contains(resource) && Actions.Contains(action);
    public static string Permission(string resource, string action) =>
        (resource == "platform_policy" ? "Platform.Policy" : resource.Replace("-", "")) + ":" +
        (action == "read_admin" ? "read" : action == "manage" ? "update" : action);

    public static bool GlobalRoleGrants(string role, string resource, string action)
    {
        if (!IsKnownOperation(resource, action)) return false;
        if (role == "PlatformAdmin") return true;
        if (resource is not ("user" or "role" or "rolegroup" or "department" or "idp" or "policy" or "platform_policy")) return false;
        return role == "PlatformSupport" && action is "list" or "read" or "read_admin" ||
               role == "PlatformAuditor" && action == "list";
    }
}
