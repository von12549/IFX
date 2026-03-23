# Plan: OPA + ABAC Authorization

**Date:** 2026-03-23
**Branch:** `feature/security/opa-abac-authorization`
**Status:** Planning

## Goal

Introduce OPA as a policy decision engine for fine-grained ABAC / resource-level authorization, layered on top of the existing RBAC model (RoleGroup → Role → Permission), without replacing it.

---

## Architecture Rules

- Domain projects must not depend on OPA, Rego, HttpClient, or any infrastructure concerns.
- Resource-level authorization is performed in Application layer after loading the target resource.
- OPA integration lives in shared cross-cutting infrastructure (`IFX.BuildingBlocks.Security`), not in the Auth module.
- ApiHost / Composition wires concrete services.
- Fail closed by default when OPA is unavailable for protected operations.
- OPA policies always evaluate `permissions` (not raw role names) — policies are decoupled from role taxonomy.

---

## Design Decisions (from analysis)

| Question | Decision |
|----------|----------|
| `ICurrentUser.TenantId` | Singular `Guid?` representing the active-request tenant (from JWT claim or primary tenant). Not all tenants the user belongs to. |
| `ICurrentUser.Department` | `IReadOnlyCollection<string>` (plural) to match domain model. |
| `ICurrentUser.MfaEnabled` | Sourced from JWT claim (`amr` or custom claim). Falls back to `false` if absent. |
| `OpaResourceAttributesBase` fields | Only `type`, `id`, `tenant_id`. Module-specific subclasses add `owner_id`, `status`, `sensitivity`, etc. |
| `ForbiddenException` handling | Throw `ForbiddenException` from `IResourceAuthorizationService`; map to 403 via global `IExceptionHandler` in ApiHost. |
| OPA unavailability in dev | `OpaOptions.FailClosed = true` by default. `NullOpaPolicyClient` (always allow) available for local dev when OPA is not running; wired via config flag `Opa:Enabled = false`. |
| Pilot "admin" check in OPA | OPA checks `input.subject.permissions` only — never raw role names. |
| `ICurrentUser` DI lifetime | Scoped (per-request). Lazy population: resolves on first access, cached within the scope. |
| `IOpaPolicyClient` DI lifetime | Singleton (HttpClient-backed). |
| Permission resolution | New Application query `GetPermissionsForUserQuery(userId, tenantId)` flattens `User → Roles → Permissions + User → RoleGroups → Roles → Permissions`. |

---

## Step-by-Step Implementation Plan

### Step 1 — New project: `IFX.BuildingBlocks.Security`

Location: `src/BuildingBlocks/IFX.BuildingBlocks.Security/`

Folder structure:
```
Authorization/
  Abstractions/
    ICurrentUser.cs
    IPermissionChecker.cs
    IOpaPolicyClient.cs
    IResourceAuthorizationService.cs
  Models/
    OpaAuthorizationEnvelope.cs         # OpaAuthorizationEnvelope<TResource>
    OpaSubjectAttributes.cs
    OpaEnvironmentAttributes.cs
    OpaResourceAttributesBase.cs        # type, id, tenant_id only
    OpaDecisionResponse.cs
    OpaDecisionResult.cs
  Opa/
    OpaOptions.cs                       # BaseUrl, TimeoutSeconds, FailClosed, Enabled
    OpaClient.cs                        # HttpClient-backed IOpaPolicyClient
    NullOpaPolicyClient.cs              # Always-allow dev stub
  Exceptions/
    ForbiddenException.cs
```

No references to Auth domain. No business logic.

---

### Step 2 — Abstractions and Models

**`ICurrentUser`**
```csharp
public interface ICurrentUser
{
    Guid UserId { get; }
    Guid? TenantId { get; }                          // active request tenant
    IReadOnlyCollection<string> Departments { get; }
    IReadOnlyCollection<string> Roles { get; }
    IReadOnlyCollection<string> Permissions { get; } // loaded from DB via PermissionChecker
    bool MfaEnabled { get; }
}
```

**`IPermissionChecker`**
```csharp
public interface IPermissionChecker
{
    Task<bool> HasPermissionAsync(string permission, CancellationToken ct = default);
}
```

**`IOpaPolicyClient`**
```csharp
public interface IOpaPolicyClient
{
    Task<OpaDecisionResult> EvaluateAsync(string decisionPath, object input, CancellationToken ct = default);
}
```

**`IResourceAuthorizationService`**
```csharp
public interface IResourceAuthorizationService
{
    Task AuthorizeAsync<TResource>(
        string requiredPermission,
        string decisionPath,
        TResource resourceAttributes,
        string action,
        CancellationToken ct = default)
        where TResource : OpaResourceAttributesBase;
}
```
Throws `ForbiddenException` on deny.

**`OpaResourceAttributesBase`** — base fields only:
```csharp
public abstract class OpaResourceAttributesBase
{
    public string Type { get; init; }
    public string Id { get; init; }
    public string TenantId { get; init; }
}
```

**Canonical OPA input envelope (JSON)**
```json
{
  "subject": {
    "id": "...",
    "tenant_id": "...",
    "departments": [],
    "roles": [],
    "permissions": [],
    "mfa": true
  },
  "resource": {
    "type": "...",
    "id": "...",
    "tenant_id": "..."
  },
  "action": "...",
  "environment": {
    "network": "...",
    "ip": "...",
    "time": "..."
  }
}
```
All JSON uses snake_case via `JsonPropertyName` attributes.

---

### Step 3 — OPA Client

**`OpaOptions`**
```csharp
public class OpaOptions
{
    public string BaseUrl { get; set; } = "http://localhost:8181";
    public int TimeoutSeconds { get; set; } = 5;
    public bool FailClosed { get; set; } = true;  // default: deny on OPA unavailable
    public bool Enabled { get; set; } = true;      // false → use NullOpaPolicyClient
}
```

**`OpaClient`** behavior:
- POST `{BaseUrl}/v1/data/{decisionPath}` with body `{ "input": <envelope> }`
- Parse `result.allow` (bool) from response
- On HTTP failure or timeout: if `FailClosed = true` → return deny; else → return allow
- Structured logging for all calls (path, decision, latency)
- Supports `CancellationToken`

**`NullOpaPolicyClient`** — always returns `OpaDecisionResult.Allow`. Used when `Opa:Enabled = false`.

---

### Step 4 — Permission Resolution Query (Auth.Application)

New query: `GetPermissionsForUserQuery(Guid userId, Guid tenantId)`

Returns `IReadOnlyCollection<string>` — flat deduplicated list of permission names.

Resolution logic:
1. Load user with roles and role groups (tenant-scoped) + their permissions
2. Flatten: `User.Roles.Where(r => r.TenantId == tenantId).SelectMany(r => r.Permissions)`
3. Also: `User.RoleGroups.Where(g => g.TenantId == tenantId).SelectMany(g => g.Roles).SelectMany(r => r.Permissions)`
4. Deduplicate by `Permission.Name`

---

### Step 5 — CurrentUser + PermissionChecker implementations

**`CurrentUser`** (in `Auth.Infrastructure` or `Auth.Composition`):
- Reads `UserId`, `TenantId`, `Roles`, `MfaEnabled` from `ClaimsPrincipal` (JWT claims)
- Reads `Departments` from user DB record (or claims if available)
- `Permissions` property: lazy — calls `GetPermissionsForUserQuery` on first access, caches in scoped instance

**`PermissionChecker`**:
- Calls `ICurrentUser.Permissions` (triggers lazy load if needed)
- Returns `true` if the permission name is present

Registration: scoped, in `Auth.Composition` (has access to both `ICurrentUser` dependencies and Auth infrastructure).

---

### Step 6 — ResourceAuthorizationService

Implementation flow:
```
1. HasPermission(requiredPermission)          → false → throw ForbiddenException
2. Build OpaAuthorizationEnvelope<TResource>  (subject from ICurrentUser, environment from HttpContext)
3. EvaluateAsync(decisionPath, envelope)      → deny → throw ForbiddenException
4. Return (allow)
```

`OpaEnvironmentAttributes` populated from `IHttpContextAccessor`:
- `ip`: `HttpContext.Connection.RemoteIpAddress`
- `network`: derived from IP (internal/external heuristic or config)
- `time`: `DateTime.UtcNow` ISO-8601

---

### Step 7 — Global Exception Handler (ApiHost)

Add `ForbiddenExceptionHandler : IExceptionHandler` in `IFX.ApiHost`:
- Catches `ForbiddenException` → returns `403 Forbidden` with `ApiResponse` error body
- Registered before generic error handler

---

### Step 8 — Rego Policy Structure

```
policies/
  authz/
    common/
      helpers.rego          # default_deny, allow rules
      tenant.rego           # same_tenant := input.subject.tenant_id == input.resource.tenant_id
      mfa.rego              # mfa_satisfied
      network.rego          # network helpers
    auth/
      read-user.rego        # pilot policy
      manage-role.rego
  tests/
    auth/
      read_user_test.rego
      manage_role_test.rego
  README.md                 # how to install OPA CLI and run opa test policies/
```

Key rule in `tenant.rego`:
```rego
same_tenant {
    input.subject.tenant_id == input.resource.tenant_id
}
```
This is enforced by OPA independently of the DB tenant filtering — defense-in-depth.

---

### Step 9 — Pilot Use Case: User Profile Read

**Policy path:** `authz/auth/read-user`

**Rule:** Allow if:
- Same tenant (`same_tenant`), AND
- Either: requester is the target user (`input.subject.id == input.resource.id`), OR
- Requester has `users.read` permission (`"users.read" in input.subject.permissions`)

**Rego:**
```rego
package authz.auth.read_user

import future.keywords

default allow := false

allow if {
    data.authz.common.tenant.same_tenant
    input.subject.id == input.resource.id
}

allow if {
    data.authz.common.tenant.same_tenant
    "users.read" in input.subject.permissions
}
```

**Application layer change (GetUserByIdQueryHandler or GetUserProfileQueryHandler):**
```
1. Load user from DB
2. Map to OpaResourceAttributesBase (type="user", id=userId, tenant_id=tenantTd)
3. Call IResourceAuthorizationService.AuthorizeAsync("users.read", "authz/auth/read_user", resource, "read")
4. Return user data
```

---

### Step 10 — DI Wiring (ApiHost / Composition)

In `IFX.ApiHost` or `Auth.Composition`:

```csharp
// OPA
services.Configure<OpaOptions>(configuration.GetSection("Opa"));
if (opaOptions.Enabled)
    services.AddSingleton<IOpaPolicyClient, OpaClient>();
else
    services.AddSingleton<IOpaPolicyClient, NullOpaPolicyClient>();

// Shared authorization
services.AddScoped<ICurrentUser, CurrentUser>();
services.AddScoped<IPermissionChecker, PermissionChecker>();
services.AddScoped<IResourceAuthorizationService, ResourceAuthorizationService>();

// HttpContextAccessor (needed for environment attributes)
services.AddHttpContextAccessor();
```

Dependency graph:
```
Domain           ← no OPA deps
Application      ← ICurrentUser, IPermissionChecker, IResourceAuthorizationService (abstractions only)
Infrastructure   ← OpaClient (HttpClient), CurrentUser, PermissionChecker
ApiHost          ← wires all, registers ForbiddenExceptionHandler
```

---

### Step 11 — Docker / Dev OPA

`deploy/opa/config.yaml`:
```yaml
services:
  - name: bundle
    url: http://localhost:8181

bundles:
  authz:
    service: bundle
    resource: /bundles/authz.tar.gz
```

`docker-compose.yml` additions:
```yaml
opa:
  image: openpolicyagent/opa:latest-static
  ports:
    - "8181:8181"
  volumes:
    - ./policies:/policies
  command: ["run", "--server", "--addr", "0.0.0.0:8181", "/policies"]
  healthcheck:
    test: ["CMD", "wget", "-qO-", "http://localhost:8181/health"]
    interval: 5s
    timeout: 3s
    retries: 5

api:
  depends_on:
    opa:
      condition: service_healthy
```

---

### Step 12 — Policy Tests and README

`policies/README.md` covers:
- Install OPA CLI: `winget install OpenPolicyAgent.OPA`
- Run all tests: `opa test policies/ -v`
- Evaluate a policy locally: `opa eval -d policies/ -I 'data.authz.auth.read_user.allow'`
- Fail-closed behavior documentation

Initial test in `tests/auth/read_user_test.rego`:
- Test: self-read → allow
- Test: admin with `users.read` permission → allow
- Test: cross-tenant → deny
- Test: no permission, not self → deny

---

## Implementation Order

1. `IFX.BuildingBlocks.Security` project scaffold (Steps 1–3)
2. `GetPermissionsForUserQuery` in Auth.Application (Step 4)
3. `CurrentUser` + `PermissionChecker` implementations (Step 5)
4. `ResourceAuthorizationService` (Step 6)
5. `ForbiddenExceptionHandler` in ApiHost (Step 7)
6. DI wiring (Step 10)
7. Rego policies scaffold (Step 8)
8. Pilot use case end-to-end (Steps 9)
9. Docker / dev OPA (Step 11)
10. Policy tests + README (Step 12)

---

## Out of Scope (this plan)

- Converting all existing authorization flows to ABAC (do one pilot only)
- Decision logging / audit trail for OPA decisions
- OPA bundle server or remote policy management
- Performance caching of OPA responses
- Frontend changes

---

## Files to Create

| File | Layer |
|------|-------|
| `src/BuildingBlocks/IFX.BuildingBlocks.Security/**` | BuildingBlocks |
| `src/Modules/Auth/IFX.Modules.Auth.Application/Users/Queries/GetPermissionsForUser/` | Application |
| `src/Modules/Auth/IFX.Modules.Auth.Infrastructure/Authorization/CurrentUser.cs` | Infrastructure |
| `src/Modules/Auth/IFX.Modules.Auth.Infrastructure/Authorization/PermissionChecker.cs` | Infrastructure |
| `src/ApiHost/IFX.ApiHost/Exceptions/ForbiddenExceptionHandler.cs` | ApiHost |
| `policies/authz/common/*.rego` | Policies |
| `policies/authz/auth/read-user.rego` | Policies |
| `policies/tests/auth/read_user_test.rego` | Policies |
| `policies/README.md` | Policies |
| `deploy/opa/config.yaml` | Deploy |
| Updated `docker-compose.yml` | Deploy |
