using System.Text.Json;
using IFX.Modules.IAM.Application.Access.Policies.DTOs;
using IFX.Modules.IAM.Domain.Access;

namespace IFX.Modules.IAM.Application.Access.Policies;

public static class PolicyChangeRules
{
    public static bool Valid(PolicyScope scope, string resource, string action, IReadOnlyCollection<PolicyConditionDto>? conditions)
    {
        if (!Enum.IsDefined(scope) || !AccessPolicySemantics.IsKnownOperation(resource, action) || conditions is null || conditions.Count is 0 or > 100) return false;
        foreach (var condition in conditions)
        {
            if (condition is null) return false;
            if (condition.TemplateName is not ("SameTenant" or "SameDepartment" or "CreatedByMe" or "IsActive" or "AnyTenant" or "GlobalRoleIncludes")) return false;
            if (scope == PolicyScope.Tenant && condition.TemplateName is "AnyTenant" or "GlobalRoleIncludes") return false;
            if (condition.TemplateName != "GlobalRoleIncludes")
            {
                if (condition.Parameters is { Count: > 0 }) return false;
                continue;
            }
            if (condition.Parameters is not { Count: 1 } || !condition.Parameters.TryGetValue("global_role", out var role)) return false;
            var roleName = role is string text ? text : role is JsonElement { ValueKind: JsonValueKind.String } json ? json.GetString() : null;
            if (roleName is not ("PlatformAdmin" or "PlatformSupport" or "PlatformAuditor")) return false;
        }
        return true;
    }
}
