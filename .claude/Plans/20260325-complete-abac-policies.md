# Complete ABAC Policies Plan

**Date:** 2026-03-25
**Branch:** `feature/complete-abac-policies`
**Status:** Planned

---

## Analysis & Advice

### Q1 — New Templates and Operators

#### Current templates (sufficient for most cases)
| Template | Condition |
|----------|-----------|
| `SameTenant` | `subject.tenant_id == resource.tenant_id` |
| `CreatedByMe` | `subject.id == resource.owner_id` |
| `SameDepartment` | `subject.departments intersects resource.departments` |

#### New template to add: `IsActive`
```
Left: resource.is_active   Operator: Equals   Right: "true" (literal)
```
Blocks operations on deactivated resources (e.g., a deactivated user, a disabled tenant).
Useful as a guard condition composable with other templates.

#### Operators — verdict
Current 6 operators (`Equals`, `NotEquals`, `In`, `NotIn`, `Contains`, `Intersects`) cover all auth
use cases in this system. `GreaterThan` / `LessThan` are numeric/date comparisons — useful for things
like "session age < 24h" or "resource.version > 0" but **not needed now**. Skip until a concrete use
case arises; the Rego policy and engine would need to be extended at that time.

---

### Q2 — Policy Mapping Per Handler

#### Guiding principles
- **RBAC gate** (permission check) is the coarse-grained layer — already in place on all endpoints.
- **ABAC** adds the fine-grained, resource-level layer on top. Its job is: given you have the permission, can you do this to *this specific resource*?
- **Platform operations** (tenant CRUD, permission CRUD) — RBAC-only. Platform admins are trusted; `SameTenant` does not apply to cross-tenant platform work. No ABAC needed.
- **Identity/system operations** (login, register, OAuth callback, token refresh, email verify) — no ABAC. These are unauthenticated or system-managed flows.

#### Policy table

| Resource | Action | ABAC Policy | Templates |
|----------|--------|-------------|-----------|
| `user` | `read` | Self: SameTenant + CreatedByMe | ✅ seeded |
| `user` | `update` | Self: SameTenant + CreatedByMe | to add |
| `user` | `list` | Admin: SameTenant | to add |
| `user` | `read_admin` | Admin: SameTenant | to add |
| `user` | `manage` | Admin: SameTenant | to add (assign roles/tenants/depts) |
| `role` | `list` | SameTenant | to add |
| `role` | `read` | SameTenant | to add |
| `role` | `create` | SameTenant | to add |
| `role` | `update` | SameTenant | to add |
| `role` | `delete` | SameTenant | to add |
| `rolegroup` | `list` | SameTenant | to add |
| `rolegroup` | `read` | SameTenant | to add |
| `rolegroup` | `create` | SameTenant | to add |
| `rolegroup` | `update` | SameTenant | to add |
| `rolegroup` | `delete` | SameTenant | to add |
| `department` | `list` | SameTenant | to add |
| `department` | `read` | SameTenant | to add |
| `department` | `create` | SameTenant | to add |
| `department` | `update` | SameTenant | to add |
| `department` | `delete` | SameTenant | to add |
| `idp` | `list` | SameTenant | to add |
| `idp` | `read` | SameTenant | to add |
| `idp` | `create` | SameTenant | to add |
| `idp` | `update` | SameTenant | to add |
| `policy` | `list` | SameTenant | to add |
| `policy` | `read` | SameTenant | to add |
| `policy` | `create` | SameTenant | to add |
| `policy` | `update` | SameTenant | to add |
| `policy` | `delete` | SameTenant | to add |

**Platform-level handlers** (GetAllTenants, CreateTenant, GetAllPermissions, CreatePermission, platform policy CRUD, etc.) — **RBAC only, no ABAC.** These operate across tenants; SameTenant would incorrectly deny platform admins. The permission gate (`Platform.X:action`) is sufficient.

**Identity handlers** (login, register, confirm, refresh, revoke, OAuth flow, sync, email verify) — **no ABAC.** These are system-managed or pre-authentication flows.

---

### Q3 — ABAC on List Endpoints

**Problem:** List endpoints return N items. Calling OPA once per item = N round-trips. Unacceptable.

**Decision: Coarse-grained single gate for lists.**

For a list endpoint (`resource/list`), a single ABAC check is made against a *virtual resource* representing the list context — not any specific item. The conditions are evaluated against the tenant context, not a specific row.

Pattern:
```csharp
// One call for the entire list
await _authorizationService.AuthorizeWithResolvedPolicyAsync(
    "role", "list",
    new TenantScopeResourceAttributes(_currentUser.TenantId),
    ct: cancellationToken);

// Then return all (already tenant-filtered by the query itself via X-Tenant-Id)
var roles = await _unitOfWork.Roles.GetAllByTenantAsync(_currentUser.TenantId, ct);
```

`TenantScopeResourceAttributes` — a new generic resource attributes class:
```csharp
public class TenantScopeResourceAttributes : OpaResourceAttributesBase
{
    public TenantScopeResourceAttributes(Guid? tenantId)
    {
        Type = "scope";
        Id = tenantId?.ToString() ?? string.Empty;
        TenantId = tenantId?.ToString() ?? string.Empty;
    }
}
```

The `SameTenant` policy condition then evaluates `subject.tenant_id == resource.tenant_id` — i.e., "does this user belong to the tenant they're querying?" — which is exactly the right check for list access.

**Row-level filtering for lists** (e.g., returning only resources the user owns) is a future concern and requires either:
- A `CreatedBy` field on all resources (see Q4), plus post-filter in the handler, OR
- A dedicated Rego policy path per resource type

For now: all list policies use `SameTenant` only (admins see everything in their tenant).

---

### Q4 — Add CreatedBy / UpdatedBy to All Tables

**Verdict: Yes, add `CreatedBy` — defer `UpdatedBy`.**

**Why `CreatedBy` is needed now:**
- The `CreatedByMe` template compares `subject.id == resource.owner_id`
- Currently only `UserResourceAttributes` sets `owner_id = userId`
- For `role/update`, `department/update`, etc., `CreatedByMe` cannot work without knowing who created the row
- Without it we can only use `SameTenant` for admin resources — which is fine for now but limits future fine-grained policies

**`UpdatedBy`:** Useful for auditing but not needed for any planned ABAC condition. Skip for now.

**Schema change required:**
- Add `CreatedBy UNIQUEIDENTIFIER NULL` FK → `auth.Users` to: `Roles`, `RoleGroups`, `Departments`, `Idps`, `PolicyDefinitions`, `Tenants`
- Add `CreatedBy` to `IAuditableEntity` interface
- Populate from `ICurrentUser.UserId` in each Create command handler
- EF migration required

**Backfill strategy for existing rows:**

| Table | Backfill value |
|-------|---------------|
| `auth.Roles` | Xiaolong Feng (`8314F7DA-2F5D-4128-A705-957CE0C3972E`) |
| `auth.RoleGroups` | Xiaolong Feng |
| `auth.Departments` | Xiaolong Feng |
| `auth.Idps` | Xiaolong Feng |
| `auth.PolicyDefinitions` | Xiaolong Feng |
| `auth.Tenants` | Xiaolong Feng |
| `auth.Users` | Self (`Id = Id`) — each user created themselves |
| `auth.UserIdentities` | The owning user (`UserId` column) |

The migration's `Up()` must include a `DATA UPDATE` step after adding the column:
```sql
-- All non-user resources: attribute to the platform admin
UPDATE auth.Roles           SET CreatedBy = '8314F7DA-2F5D-4128-A705-957CE0C3972E' WHERE CreatedBy IS NULL;
UPDATE auth.RoleGroups      SET CreatedBy = '8314F7DA-2F5D-4128-A705-957CE0C3972E' WHERE CreatedBy IS NULL;
UPDATE auth.Departments     SET CreatedBy = '8314F7DA-2F5D-4128-A705-957CE0C3972E' WHERE CreatedBy IS NULL;
UPDATE auth.Idps            SET CreatedBy = '8314F7DA-2F5D-4128-A705-957CE0C3972E' WHERE CreatedBy IS NULL;
UPDATE auth.PolicyDefinitions SET CreatedBy = '8314F7DA-2F5D-4128-A705-957CE0C3972E' WHERE CreatedBy IS NULL;
UPDATE auth.Tenants         SET CreatedBy = '8314F7DA-2F5D-4128-A705-957CE0C3972E' WHERE CreatedBy IS NULL;

-- Users created themselves
UPDATE auth.Users           SET CreatedBy = Id WHERE CreatedBy IS NULL;

-- UserIdentities owned by the linked user
UPDATE auth.UserIdentities  SET CreatedBy = UserId WHERE CreatedBy IS NULL;
```

**Decision: Implement CreatedBy as Phase 1 of this plan.** All new resource attribute classes will expose `owner_id` = `CreatedBy.ToString()` once the column exists.

---

## Implementation Phases

### Phase 1 — DB: Add CreatedBy

**Files:**
- `IAuditableEntity.cs` — add `Guid? CreatedBy { get; set; }`
- All domain entities (`Role`, `RoleGroup`, `Department`, `Idp`, `PolicyDefinition`, `Tenant`, `User`, `UserIdentity`) — add property + EF config
- All Create command handlers — set `CreatedBy = _currentUser.UserId`
- EF configs for all affected tables — add nullable column + FK to `auth.Users`
- New EF migration: `AddCreatedByToResources`
  - Adds `CreatedBy` column (nullable) to all tables listed above
  - Backfills existing rows: non-user resources → Xiaolong Feng (`8314F7DA-...`), Users → self, UserIdentities → their `UserId`

### Phase 2 — New Template: `IsActive`

**Files:**
- `BuiltInTemplates.cs` — add `IsActive` template
- Rego `abac_eval.rego` — already handles `equals`; no Rego change needed (is_active is a string "true"/"false")
- All resource attribute base classes — expose `IsActive` property mapped to `is_active`

### Phase 3 — Resource Attribute Models

Create one `*ResourceAttributes` class per resource type:

| Class | `Type` | Properties |
|-------|--------|------------|
| `TenantScopeResourceAttributes` | `"scope"` | `TenantId` (for list gates) |
| `RoleResourceAttributes` | `"role"` | `TenantId`, `OwnerId` |
| `RoleGroupResourceAttributes` | `"rolegroup"` | `TenantId`, `OwnerId` |
| `DepartmentResourceAttributes` | `"department"` | `TenantId`, `OwnerId` |
| `IdpResourceAttributes` | `"idp"` | `TenantId`, `OwnerId` |
| `PolicyResourceAttributes` | `"policy"` | `TenantId`, `OwnerId` |

All in `src/Modules/Auth/IFX.Modules.Auth.Application/{subdomain}/Authorization/`.

### Phase 4 — Apply ABAC to Handlers

Add `IResourceAuthorizationService` injection and `AuthorizeWithResolvedPolicyAsync` call to each handler listed in the policy table. Group:

**Users subdomain:**
- `UpdateUserProfileCommandHandler` — `user/update`, `UserResourceAttributes`
- `GetAllUsersQueryHandler` — `user/list`, `TenantScopeResourceAttributes`
- `GetUserByIdQueryHandler` — `user/read_admin`, `UserResourceAttributes`
- `AssignRolesToUserCommandHandler`, `AssignRoleGroupsToUserCommandHandler`, `AssignTenantToUserCommandHandler`, `AssignDepartmentToUserCommandHandler`, `RemoveRole/RoleGroup/Tenant/DepartmentFromUser` — `user/manage`, `UserResourceAttributes`

**Authorization subdomain — Roles:**
- `GetAllRolesQueryHandler` — `role/list`, `TenantScopeResourceAttributes`
- `GetRoleByIdQueryHandler` — `role/read`, `RoleResourceAttributes`
- `CreateRoleCommandHandler` — `role/create`, `TenantScopeResourceAttributes`
- `UpdateRoleCommandHandler` — `role/update`, `RoleResourceAttributes`
- `DeleteRoleCommandHandler` — `role/delete`, `RoleResourceAttributes`
- `AssignPermissionsToRoleCommandHandler`, `RemovePermissionFromRoleCommandHandler` — `role/manage`, `RoleResourceAttributes`

**Authorization subdomain — RoleGroups:**
- All 5 handlers — same pattern as Roles, resource type `rolegroup`

**Authorization subdomain — Departments:**
- All 5 handlers — resource type `department`

**Identity subdomain — Idps:**
- `GetAllIdpsQueryHandler` — `idp/list`, `TenantScopeResourceAttributes`
- `GetIdpByIdQueryHandler` — `idp/read`, `IdpResourceAttributes`
- `CreateIdpCommandHandler` — `idp/create`, `TenantScopeResourceAttributes`
- `UpdateIdpCommandHandler` — `idp/update`, `IdpResourceAttributes`

**Authorization subdomain — Policies:**
- `GetPoliciesQueryHandler` — `policy/list`, `TenantScopeResourceAttributes`
- `CreatePolicyCommandHandler` — `policy/create`, `TenantScopeResourceAttributes`
- `UpdatePolicyCommandHandler` — `policy/update`, `PolicyResourceAttributes`
- `DeletePolicyCommandHandler` — `policy/delete`, `PolicyResourceAttributes`

### Phase 5 — Seed Policies (EF Migration)

New EF migration: `SeedAbacPolicies`

Seed one `PolicyDefinition` row per `(resource, action)` pair at the **platform level** (`TenantId IS NULL`).
Platform-level rows act as the default for all tenants; tenant-level overrides can be added via the UI.

All new policies use `SameTenant` condition (except `user/read` and `user/update` which also include `CreatedByMe`).

IFX-tenant-specific overrides are seeded for `user/update` (SameTenant + CreatedByMe) since IFX users should only edit their own profile.

| ResourceType | Action | TenantId | Conditions |
|---|---|---|---|
| `user` | `update` | NULL (platform) | SameTenant + CreatedByMe |
| `user` | `list` | NULL | SameTenant |
| `user` | `read_admin` | NULL | SameTenant |
| `user` | `manage` | NULL | SameTenant |
| `role` | `list/read/create/update/delete/manage` | NULL | SameTenant |
| `rolegroup` | `list/read/create/update/delete/manage` | NULL | SameTenant |
| `department` | `list/read/create/update/delete/manage` | NULL | SameTenant |
| `idp` | `list/read/create/update` | NULL | SameTenant |
| `policy` | `list/read/create/update/delete` | NULL | SameTenant |

### Phase 6 — CXI Tenant Policies

Add a new section to `scripts/seed-cxi-tenant.sql` (or a separate `scripts/seed-cxi-policies.sql`) that seeds CXI-specific `PolicyDefinition` overrides if they differ from the platform defaults. Since CXI uses the same `SameTenant` pattern, **no CXI-specific overrides are needed** — CXI inherits all platform defaults automatically via the 3-tier resolver.

---

## Files to Create / Modify (Summary)

```
src/BuildingBlocks/IFX.BuildingBlocks.Security/
  Authorization/Abac/Registry/BuiltInTemplates.cs          [modify] add IsActive
  Authorization/Models/OpaResourceAttributesBase.cs         [modify] add IsActive property

src/Modules/Auth/IFX.Modules.Auth.Domain/
  Common/IAuditableEntity.cs                                [modify] add CreatedBy
  Authorization/Role.cs                                     [modify] add CreatedBy
  Authorization/RoleGroup.cs                                [modify] add CreatedBy
  Authorization/Department.cs                               [modify] add CreatedBy
  Authorization/Tenant.cs                                   [modify] add CreatedBy
  Authorization/PolicyDefinition.cs                         [modify] add CreatedBy
  Identity/Idp.cs                                           [modify] add CreatedBy

src/Modules/Auth/IFX.Modules.Auth.Infrastructure/
  Authorization/{Role,RoleGroup,Department,Tenant,PolicyDefinition}Configuration.cs  [modify]
  Identity/IdpConfiguration.cs                              [modify]
  Persistence/Migrations/AddCreatedByToResources.cs         [new EF migration]
  Persistence/Migrations/SeedAbacPolicies.cs                [new EF migration]

src/Modules/Auth/IFX.Modules.Auth.Application/
  Users/Authorization/
    TenantScopeResourceAttributes.cs                        [new]
  Authorization/Authorization/
    RoleResourceAttributes.cs                               [new]
    RoleGroupResourceAttributes.cs                          [new]
    DepartmentResourceAttributes.cs                         [new]
    PolicyResourceAttributes.cs                             [new]
  Identity/Authorization/
    IdpResourceAttributes.cs                                [new]
  Users/Queries/GetAllUsers/GetAllUsersQueryHandler.cs       [modify]
  Users/Queries/GetUserById/GetUserByIdQueryHandler.cs       [modify]
  Users/Commands/UpdateUserProfile/...Handler.cs             [modify]
  Users/Commands/Assign*/...Handler.cs (×4)                 [modify]
  Users/Commands/Remove*/...Handler.cs (×4)                 [modify]
  Authorization/Queries/GetAllRoles/...Handler.cs            [modify]
  Authorization/Queries/GetRoleById/...Handler.cs            [modify]
  Authorization/Commands/CreateRole/...Handler.cs            [modify]
  Authorization/Commands/UpdateRole/...Handler.cs            [modify]
  Authorization/Commands/DeleteRole/...Handler.cs            [modify]
  Authorization/Commands/AssignPermissionsToRole/...Handler.cs [modify]
  Authorization/Commands/RemovePermissionFromRole/...Handler.cs [modify]
  (same pattern for RoleGroup, Department, Idp, Policy)

policies/authz/common/abac_eval.rego                        [no change needed]
```

---

## What NOT to include in this plan

- Numeric operators (`GreaterThan`, `LessThan`) — no concrete use case yet
- `UpdatedBy` column — useful for audit but no ABAC condition needs it
- Per-item ABAC filtering on list results — future work; requires row-level OPA evaluation
- Platform-level handler ABAC (tenant CRUD, permission CRUD) — RBAC permission gate is sufficient
- Identity/auth flow ABAC (login, register, OAuth) — pre-authentication, no resource context
