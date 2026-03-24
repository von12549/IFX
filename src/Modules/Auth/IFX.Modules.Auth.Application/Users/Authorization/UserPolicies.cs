using IFX.BuildingBlocks.Security.Authorization.Abac.Policies;
using IFX.BuildingBlocks.Security.Authorization.Abac.Registry;

namespace IFX.Modules.Auth.Application.Users.Authorization;

/// <summary>
/// ABAC policies for the User resource type.
/// </summary>
public static class UserPolicies
{
    /// <summary>
    /// Allow when the requesting user is reading their own profile in the same tenant.
    /// Conditions: SameTenant AND CreatedByMe (subject.id == resource.owner_id).
    /// </summary>
    public static readonly AbacPolicy ReadOwnProfile = new()
    {
        ResourceType = "user",
        Action = "read",
        Conditions =
        [
            new AbacCondition { Template = BuiltInTemplates.SameTenant },
            new AbacCondition { Template = BuiltInTemplates.CreatedByMe }
        ]
    };

    /// <summary>
    /// Allow when the requesting user is in the same tenant as the target user.
    /// Intended to be combined with an RBAC pre-gate (e.g. "users.read").
    /// </summary>
    public static readonly AbacPolicy ReadAnyProfile = new()
    {
        ResourceType = "user",
        Action = "read",
        Conditions =
        [
            new AbacCondition { Template = BuiltInTemplates.SameTenant }
        ]
    };
}
