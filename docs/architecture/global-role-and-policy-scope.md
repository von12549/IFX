# GlobalRole & PolicyScope — Authorization Flow

## Overview

IFX uses a two-layered authorization model:

1. **RBAC** — coarse-grained gate. Does the caller hold the required permission string?
2. **ABAC via OPA** — fine-grained gate. Does the loaded resource satisfy the active policy conditions?

**GlobalRole** and **PolicyScope** are additions that extend this model to cover *cross-tenant platform operators* — users who administer the platform itself rather than a single tenant.

---

## GlobalRole

### What it is

A `GlobalRole` is a platform-level role that is **not scoped to any tenant**. It identifies users who operate across the entire platform.

Three built-in roles are seeded at startup:

| Name | Purpose |
|------|---------|
| `PlatformAdmin` | Full platform control — can assign/remove all global roles, manage platform policies |
| `PlatformSupport` | Read-only platform access for support operations |
| `PlatformAuditor` | Audit and compliance visibility across all tenants |

### Data model

```
GlobalRole            UserGlobalRole            User
──────────────        ─────────────────         ──────
Id (PK)         ←─── GlobalRoleId (FK)   UserId (FK) ───► Id (PK)
Name                  UserId (FK)
Description           AssignedAt
```

`UserGlobalRole` is a simple join entity with no additional business logic beyond an `AssignedAt` timestamp.

### How GlobalRoles are loaded

`CurrentUser.GlobalRoles` is populated **lazily** on the first access within a request, then cached in `IMemoryCache` for **5 minutes** (TTL) per `userId`. This avoids a DB query on every authorization check within the same request.

```
Request arrives
  └─ ICurrentUser.GlobalRoles accessed
       ├─ already set on this request instance? return it
       ├─ cache hit "globalroles:{userId}"? return cached list
       └─ DB query: UserGlobalRole ⋈ GlobalRole WHERE UserId = {userId}
            └─ store in cache (5-min TTL) and return
```

### IsGlobalAdmin shortcut

```csharp
public bool IsGlobalAdmin => GlobalRoles.Contains(GlobalRoleNames.PlatformAdmin);
```

This is the only shortcut derived from `GlobalRoles`. `PlatformSupport` and `PlatformAuditor` are checked via `GlobalRoles.Contains(...)` directly in handler or policy code.

### Management endpoints

All endpoints are under `/api/v1/platform/globalrole` and require the caller to be a `PlatformAdmin` (`IsGlobalAdmin == true`):

| Method | Route | Description |
|--------|-------|-------------|
| `GET` | `/api/v1/platform/globalrole` | List all global roles |
| `GET` | `/api/v1/platform/globalrole/user/{userId}` | Get global roles assigned to a user |
| `POST` | `/api/v1/platform/globalrole/user/{userId}` | Assign a global role to a user |
| `DELETE` | `/api/v1/platform/globalrole/user/{userId}/{roleId}` | Remove a global role from a user |

#### Safety guard

Removing `PlatformAdmin` from a user is blocked if it would leave zero `PlatformAdmin` assignments on the platform. The handler calls `CountPlatformAdminsAsync()` and returns a failure result rather than completing the removal.

---

## PolicyScope

### What it replaces

Previously, platform-level (global default) `PolicyDefinition` rows were identified by `TenantId IS NULL`. This relied on a nullable column convention that was ambiguous and hard to query explicitly.

`PolicyScope` replaces this with an **explicit enum column**:

```csharp
public enum PolicyScope
{
    Tenant = 0,   // Scoped to a specific tenant — TenantId required
    Platform = 1  // Platform-level default — TenantId is NULL
}
```

### Domain rules

- `Scope = Tenant` **requires** a non-null `TenantId` (enforced in `PolicyDefinition.Create`).
- `Scope = Platform` sets `TenantId = null`. These rows act as global defaults for tenants that have no tenant-specific override.
- The unique index on `PolicyDefinition` is `(Scope, TenantId, ResourceType, Action)` — ensuring only one row per scope/tenant/resource/action combination.

### How platform policies are queried

`IPolicyDefinitionRepository` exposes two separate methods:

```csharp
// Returns a Tenant-scoped row for the given tenantId
Task<PolicyDefinition?> GetAsync(Guid tenantId, string resourceType, string action, ct);

// Returns the Platform-scoped row (Scope = Platform, TenantId IS NULL)
Task<PolicyDefinition?> GetPlatformAsync(string resourceType, string action, ct);
```

The `DbAbacPolicyResolver` uses these in its resolution chain (see below).

---

## Full Authorization Flow

Every Application-layer handler that protects a resource calls:

```csharp
await _authorizationService.AuthorizeWithResolvedPolicyAsync(
    resourceType,   // e.g. "role", "department"
    action,         // e.g. "read", "update"
    resourceAttributes,
    parameters,
    cancellationToken);
```

The flow inside `ResourceAuthorizationService.AuthorizeWithResolvedPolicyAsync` is:

```
┌─────────────────────────────────────────────────────────┐
│ AuthorizeWithResolvedPolicyAsync(resourceType, action)  │
└───────────────────────┬─────────────────────────────────┘
                        │
          Does caller have any GlobalRoles?
                  ┌─────┴──────┐
                 YES            NO
                  │              │
                  ▼              ▼
    ResolvePlatformPolicyAsync  Does caller have a TenantId?
                               ┌──────┴──────┐
                              YES             NO
                               │              │
                               ▼              ▼
                  ResolveTenantPolicyAsync   policy = null
                                            → ForbiddenException
                        │
                        ▼
             policy is null?
               → ForbiddenException
                 "No ABAC policy defined"
                        │
                        ▼
         AuthorizeWithPolicyAsync(policy, resourceAttributes)
```

### Policy resolution — 3-tier chain

#### For GlobalRole users → `ResolvePlatformPolicyAsync`

```
1. Cache hit "abac:platform:{resource}:{action}" ?  → return cached
2. DB: PolicyDefinition WHERE Scope=Platform AND ResourceType=X AND Action=Y → use if found
3. StaticAbacPolicyResolver (in-memory registered defaults)
4. null → implicit deny
```

#### For regular tenant users → `ResolveTenantPolicyAsync`

```
1. Cache hit "abac:{tenantId}:{resource}:{action}" ?   → return cached
2. DB: PolicyDefinition WHERE Scope=Tenant AND TenantId=X AND ResourceType=Y AND Action=Z → use if found
3. Cache hit "abac:platform:{resource}:{action}" ?     → return cached
4. DB: PolicyDefinition WHERE Scope=Platform AND ResourceType=Y AND Action=Z → use if found
5. StaticAbacPolicyResolver (in-memory registered defaults)
6. null → implicit deny
```

The tenant path deliberately falls through to the platform row — a `Scope=Platform` row acts as a **global default** for all tenants that have not defined their own override.

### OPA evaluation — `abac_eval` Rego policy

Once a policy is resolved, its conditions are evaluated by OPA at `authz/common/abac_eval`:

```rego
# GlobalAdmins bypass all condition checks
allow if {
    input.subject.is_global_admin == "true"
}

# All conditions must pass (AND semantics)
allow if {
    count(input.conditions) > 0
    every condition in input.conditions {
        condition_passes(condition)
    }
}
```

The `is_global_admin` field is set in the OPA subject envelope from `ICurrentUser.IsGlobalAdmin`. This means a `PlatformAdmin` is **always allowed** by OPA regardless of what conditions the policy defines.

The full OPA input envelope looks like:

```json
{
  "subject": {
    "id": "<userId>",
    "tenant_id": "<activeTenantId>",
    "roles": ["Admin"],
    "permissions": ["Role:read", "Role:update"],
    "global_roles": ["PlatformAdmin"],
    "is_global_admin": "true",
    "departments": [],
    "mfa": false
  },
  "resource": {
    "type": "role",
    "id": "<resourceId>",
    "tenant_id": "<resourceTenantId>",
    "created_by": "<creatorUserId>",
    "is_active": "true"
  },
  "action": "update",
  "conditions": [
    { "operator": "equals", "left": "subject.tenant_id", "right_type": "field_ref", "right": "resource.tenant_id" }
  ]
}
```

---

## Decision Matrix

| Caller type | Has GlobalRoles | Has TenantId | Policy path used | OPA bypass |
|-------------|-----------------|--------------|-------------------|-----------|
| Regular tenant user | No | Yes | Tenant → Platform → Static → deny | No (conditions evaluated) |
| Regular tenant user | No | No | — | No (denied immediately, no policy) |
| PlatformAdmin | Yes (`PlatformAdmin`) | Any | Platform → Static → deny | **Yes** (OPA returns allow unconditionally) |
| PlatformSupport | Yes (`PlatformSupport`) | Any | Platform → Static → deny | No (conditions evaluated against platform policy) |
| PlatformAuditor | Yes (`PlatformAuditor`) | Any | Platform → Static → deny | No (conditions evaluated against platform policy) |

---

## Cache Invalidation

Policy cache entries must be explicitly invalidated after any mutation. Handlers call `IAbacPolicyCache` (implemented by `DbAbacPolicyResolver`):

| Operation | Method to call |
|-----------|---------------|
| Tenant policy created/updated/deleted | `Invalidate(tenantId, resourceType, action)` |
| Platform policy created/updated/deleted | `InvalidatePlatform(resourceType, action)` |

GlobalRole cache entries (per-user, 5-min TTL) are **not manually invalidated** — they expire naturally. After assigning or removing a GlobalRole, the change takes effect within 5 minutes for the affected user's next request.

---

## Adding a New Platform Policy

1. Insert a `PolicyDefinition` row with `Scope = Platform`, `TenantId = NULL`, and the desired `ConditionsJson`.
2. Call `InvalidatePlatform(resourceType, action)` to clear any stale cache.
3. The next resolution for that `resourceType/action` will pick up the new row for all users — both GlobalRole users (via `ResolvePlatformPolicyAsync`) and tenant users without a tenant-specific override (via the platform fallback in `ResolveTenantPolicyAsync`).

## Adding a New Tenant Policy Override

1. Insert a `PolicyDefinition` row with `Scope = Tenant`, the desired `TenantId`, and `ConditionsJson`.
2. Call `Invalidate(tenantId, resourceType, action)` to clear the tenant cache entry.
3. That tenant's users will now use the tenant-specific conditions instead of the platform default.
