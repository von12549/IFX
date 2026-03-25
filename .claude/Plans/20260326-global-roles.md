# GlobalRole System Plan

**Date:** 2026-03-26
**Branch:** `feature/abac/scope-globalroles`
**Base:** `feature/complete-abac-policies`
**Depends on:** `20260326-policy-definition-scope.md` (Scope field must be in place first)
**Status:** Planning

---

## Goal

Introduce `GlobalRole` — a cross-tenant role concept for platform operators. Users with a `GlobalRole` can act across all tenants with permissions defined by Platform-scoped policies. The system avoids hard-coded bypass logic and keeps OPA as the single authorization decision point.

---

## Motivation

Currently there is no first-class concept for platform-level actors (admins, support, auditors). Work-arounds:
- Assigning a user to every tenant manually — does not scale
- `TenantId = NULL` on roles — same implicit-NULL problem as policies

`GlobalRole` gives platform operators a clean identity: they have no tenant, they resolve Platform policies, and OPA governs what they can do.

---

## Seeded GlobalRoles

| Name | Purpose |
|------|---------|
| `PlatformAdmin` | Full platform access — effectively all permissions |
| `PlatformSupport` | Read-only cross-tenant access for support operations |
| `PlatformAuditor` | Read-only audit access — policies, users, tenants |

Stable UUID v7 constants generated once and hardcoded in migration (same pattern as policy seeds).

---

## Authorization Workflow (Updated)

```
AuthorizeWithResolvedPolicyAsync(resource, action, attributes, ctx)
  │
  ├── Does user have GlobalRoles?
  │     YES → resolve Platform policy (Scope = Platform, match resource+action)
  │     NO  → resolve Tenant policy  (Scope = Tenant,   TenantId = user.TenantId)
  │
  └── Send to OPA:
        input.user.global_roles   = ["PlatformAdmin", ...]  (or [])
        input.user.is_global_admin = true/false
        input.user.tenant_id       = ... (null for global users)
        input.resource.*           = resource attributes
```

**No application-layer bypass for PlatformAdmin.** The OPA Rego policy handles "allow all" for `is_global_admin = true`. This preserves the audit trail and keeps authorization logic in one place.

---

## Affected Areas

### 1. Domain — `GlobalRole` entity

New file: `src/Modules/Auth/IFX.Modules.Auth.Domain/Authorization/GlobalRole.cs`

```csharp
public class GlobalRole : AuditableEntity
{
    public string Name { get; private set; }
    public string Description { get; private set; }
    public ICollection<UserGlobalRole> UserGlobalRoles { get; private set; }

    public static GlobalRole Create(string name, string description, Guid createdById) { ... }
}
```

New file: `src/Modules/Auth/IFX.Modules.Auth.Domain/Authorization/UserGlobalRole.cs`

```csharp
public class UserGlobalRole
{
    public Guid UserId { get; private set; }
    public Guid GlobalRoleId { get; private set; }
    public User User { get; private set; }
    public GlobalRole GlobalRole { get; private set; }
}
```

### 2. Domain — `User` entity update

Add navigation: `public ICollection<UserGlobalRole> GlobalRoles { get; private set; }`

Add helper: `public bool IsGlobalAdmin => GlobalRoles.Any(gr => gr.GlobalRole.Name == GlobalRoleNames.PlatformAdmin)`

Add constants file: `GlobalRoleNames.cs` — `PlatformAdmin`, `PlatformSupport`, `PlatformAuditor`

### 3. Application — `ICurrentUser`

**File:** `src/BuildingBlocks/IFX.BuildingBlocks.Security/Authorization/Abstractions/ICurrentUser.cs`

Add:
```csharp
IReadOnlyList<string> GlobalRoles { get; }
bool IsGlobalAdmin { get; }
```

**Implementation** (`CurrentUser.cs` in Infrastructure):
- Load `GlobalRoles` from JWT claims (new claim type: `global_roles`) OR load lazily from DB
- `IsGlobalAdmin` derived from `GlobalRoles.Contains(GlobalRoleNames.PlatformAdmin)`

### 4. Application — `IResourceAuthorizationService` / `AuthorizeWithResolvedPolicyAsync`

**File:** `src/BuildingBlocks/.../Authorization/Services/ResourceAuthorizationService.cs`

Update resolver dispatch:
```csharp
PolicyDefinition? policy;
if (_currentUser.GlobalRoles.Any())
    policy = await _resolver.ResolvePlatformPolicyAsync(resourceType, action, ct);
else
    policy = await _resolver.ResolveTenantPolicyAsync(_currentUser.TenantId, resourceType, action, ct);
```

Update OPA input construction — add to existing `OpaInput`:
```csharp
user.global_roles   = _currentUser.GlobalRoles
user.is_global_admin = _currentUser.IsGlobalAdmin
```

### 5. Application — `IAbacPolicyResolver`

Add overloads (or rename existing):
```csharp
Task<PolicyDefinition?> ResolvePlatformPolicyAsync(string resourceType, string action, CancellationToken ct);
Task<PolicyDefinition?> ResolveTenantPolicyAsync(Guid? tenantId, string resourceType, string action, CancellationToken ct);
```

### 6. Infrastructure — Repository

New interface: `IGlobalRoleRepository`
```csharp
Task<GlobalRole?> GetByNameAsync(string name, CancellationToken ct);
Task<IReadOnlyList<GlobalRole>> GetByUserIdAsync(Guid userId, CancellationToken ct);
Task AddAsync(GlobalRole role, CancellationToken ct);
```

Add `GlobalRoles` property to `IUnitOfWork`.

### 7. Infrastructure — EF Core Configuration

New files:
- `GlobalRoleConfiguration.cs` — `auth.GlobalRoles` table, unique index on `Name`
- `UserGlobalRoleConfiguration.cs` — `auth.UserGlobalRoles` join table, PK `(UserId, GlobalRoleId)`

### 8. OPA Rego — Update generic policy

**File:** `src/Modules/Auth/IFX.Modules.Auth.Infrastructure/Opa/Policies/abac_policy.rego`

Add rule at top of `allow`:
```rego
# Global admins are always allowed
allow {
    input.user.is_global_admin == true
}
```

Existing rules remain unchanged — they apply to non-admin global roles and tenant users.

For `SameTenant` template: if `input.user.global_roles` is non-empty and `is_global_admin` is false, the existing `SameTenant` condition would fail (user has no tenant_id). Need a new template or condition:

Option: Add `AnyTenant` template — allows cross-tenant access for global roles:
```rego
evaluate_condition("AnyTenant", _, _) {
    count(input.user.global_roles) > 0
}
```

Global role policies use `AnyTenant` instead of `SameTenant`.

### 9. Application — CRUD Commands/Queries for GlobalRole management

New commands:
- `AssignGlobalRoleCommand(userId, globalRoleId)` → `UserGlobalRole`
- `RemoveGlobalRoleCommand(userId, globalRoleId)`
- `ListGlobalRolesQuery()` → `IReadOnlyList<GlobalRoleDto>`
- `GetUserGlobalRolesQuery(userId)` → `IReadOnlyList<GlobalRoleDto>`

### 10. Presentation — API Endpoints

New controller or extension on existing: `GlobalRoleController`

```
GET    /api/v1/platform/globalroles             — list all GlobalRoles
GET    /api/v1/platform/users/{userId}/globalroles — get user's GlobalRoles
POST   /api/v1/platform/users/{userId}/globalroles — assign GlobalRole
DELETE /api/v1/platform/users/{userId}/globalroles/{roleId} — remove GlobalRole
```

Protected by RBAC permission `Platform.GlobalRole:manage` (PlatformAdmin only initially).

### 11. Migration — Seed GlobalRoles

New EF migration: `SeedGlobalRoles`

```sql
INSERT INTO auth.GlobalRoles (Id, Name, Description, ...)
VALUES
  ('<stable-uuid-1>', 'PlatformAdmin',   'Full cross-tenant platform access'),
  ('<stable-uuid-2>', 'PlatformSupport', 'Read-only cross-tenant support access'),
  ('<stable-uuid-3>', 'PlatformAuditor', 'Read-only audit access')
WHERE NOT EXISTS (...)
```

### 12. Tests

New unit test files:
- `AssignGlobalRoleCommandHandlerTests`
- `RemoveGlobalRoleCommandHandlerTests`
- `ListGlobalRolesQueryHandlerTests`

Update existing handler tests:
- `ICurrentUser` mock: add `GlobalRoles` and `IsGlobalAdmin` setup (default: empty list, false)

OPA integration tests:
- `PlatformAdmin` → allow regardless of resource attributes
- `PlatformSupport` with `AnyTenant` policy → allow read, deny write
- Tenant user → unchanged behavior

---

## Implementation Order

1. Domain: `GlobalRole`, `UserGlobalRole`, `GlobalRoleNames` constants, `User` navigation
2. `ICurrentUser` interface + `CurrentUser` implementation update
3. `IGlobalRoleRepository` interface + `IUnitOfWork` update
4. EF configurations: `GlobalRoleConfiguration`, `UserGlobalRoleConfiguration`
5. EF migration: `AddGlobalRoles`
6. EF migration: `SeedGlobalRoles`
7. OPA Rego: add `is_global_admin` allow rule + `AnyTenant` template
8. `IAbacPolicyResolver` + `AbacPolicyResolver` — platform/tenant dispatch
9. `ResourceAuthorizationService` — global role dispatch, OPA input update
10. CRUD commands/queries (Assign, Remove, List, GetUserGlobalRoles)
11. `GlobalRoleController` endpoints
12. Tests

---

## Open Questions

**Q1: JWT claim vs DB load for GlobalRoles in `ICurrentUser`** ✓ Decided: DB load
- GlobalRoles is a pure authorization concern owned by our system, not the IdP — no IdP changes needed
- `TenantId` context already comes from the `X-Tenant-Id` header (not a JWT claim), so DB-resolved auth context is the established pattern
- JWT claim approach would require Cognito Lambda trigger + Auth0 Action updates, couples our schema to IdP logic, and role changes only take effect on token refresh
- **Implementation:** lazy DB load in `CurrentUser`, cached per-user with a short TTL (~5 min); changes take effect on next request

**Q2: Cross-tenant resource access — which TenantId does a GlobalRole user target?** ✓ Decided: X-Tenant-Id header, same as regular users
- GlobalRole users still send `X-Tenant-Id` header to select which tenant's data to view — consistent with existing pattern
- `AnyTenant` condition bypasses `SameTenant` in OPA, so the action is authorized regardless of which tenant is in the header
- If no `X-Tenant-Id` header is sent, behavior is the same as for regular users (empty/null result) — GlobalRole users must still select a tenant
- "View all tenants" mode is out of scope; no new mechanism required

**Q3: Should `PlatformAdmin` GlobalRole assignment itself be restricted?** ✓ Decided: two guards required
- **Assign guard:** caller must be `IsGlobalAdmin` to assign the `PlatformAdmin` role; `PlatformSupport`/`PlatformAuditor` can be assigned by any PlatformAdmin
- **Remove guard:** reject removal of `PlatformAdmin` if it would leave zero PlatformAdmins in the system (prevents ungovernable state)
- **Bootstrap:** first PlatformAdmin assigned via seed migration (hardcoded user→GlobalRole row); no chicken-and-egg problem
- Enforced in `AssignGlobalRoleCommandHandler` and `RemoveGlobalRoleCommandHandler`

---

## What Does NOT Change

- Tenant-scoped roles and their permissions — unchanged
- `PolicyDefinition` CRUD for tenant policies — unchanged
- Existing OPA templates (`SameTenant`, `CreatedByMe`) — unchanged
- Existing 3-tier resolver structure — extended, not replaced
