# ABAC Authorization Architecture

IFX uses a two-layered authorization model:

1. **RBAC (coarse-grained)** — Permission strings checked via `IPermissionChecker`. Gates API access.
2. **ABAC (fine-grained)** — Resource-level policy decisions evaluated after the resource is loaded (post-load pattern). Prevents phantom authorization on non-existent resources.

---

## Components

### IFX.BuildingBlocks.Security

Cross-cutting security project. Zero references to any business module.

| Component | Description |
|-----------|-------------|
| `ICurrentUser` | Exposes `UserId`, `TenantId`, `Roles`, `Permissions`, `MfaEnabled` |
| `IPermissionChecker` | Checks coarse-grained RBAC permissions for the current user |
| `IResourceAuthorizationService` | Orchestrates RBAC gate + OPA evaluation; throws `ForbiddenException` on deny |
| `IOpaPolicyClient` | Sends authorization envelope to OPA; returns `OpaDecisionResult` |
| `OpaClient` | HttpClient-backed OPA client; configurable base URL and timeout; fail-closed |
| `NullOpaPolicyClient` | Dev stub — always allows; registered when `Opa:Enabled = false` |
| `IAbacTemplateRegistry` | Registry of named `ConditionTemplate` objects (reusable condition definitions) |
| `IAbacPolicyEngine` | Evaluates an `AbacPolicy` against subject/resource attributes without calling OPA |
| `IAbacPolicyResolver` | Resolves the active `AbacPolicy` for a `(tenantId, resourceType, action)` triple |
| `IAbacPolicyCache` | Invalidates cached policy entries (tenant-scoped or platform-scoped) |

### OPA Envelope (canonical input contract)

```json
{
  "subject":  { "id": "...", "tenant_id": "...", "roles": [], "permissions": [], "mfa": true },
  "resource": { "type": "...", "id": "...", "tenant_id": "...", "owner_id": "...", "status": "..." },
  "action":   "read",
  "environment": { "ip": "...", "time": "..." }
}
```

OPA policies evaluate `input.subject.permissions` only — never role names. This decouples policy logic from role taxonomy.

---

## Template-Based ABAC Engine

Instead of writing a separate Rego file per resource type, new resources use reusable C# condition templates evaluated by a single generic Rego policy (`template_abac.rego`).

### Built-in templates

| Template | Condition |
|----------|-----------|
| `SameTenant` | `subject.tenant_id == resource.tenant_id` |
| `CreatedByMe` | `subject.id == resource.owner_id` |

### How it works

1. A `ConditionTemplate` defines a left-hand side, operator, and right-hand side resolved from OPA input fields.
2. An `AbacPolicy` holds a list of `AbacCondition` objects (each referencing a template).
3. `AbacPolicyEngine.EvaluateAsync` evaluates all conditions; all must pass for allow.
4. The Rego policy (`policies/authz/common/template_abac.rego`) simply calls the engine result.

### Adding a new condition template

Register in `BuiltInTemplates.Register(registry)` in Infrastructure's `DependencyInjection`:
```csharp
registry.Register(new ConditionTemplate
{
    Name = "MyCondition",
    Left  = new FieldRef { Source = FieldSource.Subject, Path = "id" },
    Op    = ConditionOperator.Equals,
    Right = new FieldRef { Source = FieldSource.Resource, Path = "owner_id" }
});
```

---

## DB-Backed Policy Resolution (3-Tier)

Policies are stored in `auth.PolicyDefinitions`. `DbAbacPolicyResolver` resolves in order:

```
Tier 1: Tenant DB row     (TenantId = <currentTenantId>)
    ↓ miss
Tier 2: Platform DB row   (TenantId IS NULL)
    ↓ miss
Tier 3: Static fallback   (StaticAbacPolicyResolver — registered defaults)
    ↓ miss
Result: null → deny
```

### PolicyDefinition table

| Column | Type | Notes |
|--------|------|-------|
| `Id` | `uniqueidentifier` | PK |
| `TenantId` | `uniqueidentifier?` | NULL = platform-level (global default) |
| `Name` | `nvarchar(200)` | Display name |
| `Description` | `nvarchar(500)?` | Optional description |
| `ResourceType` | `nvarchar(100)` | e.g. `user`, `document` |
| `Action` | `nvarchar(100)` | e.g. `read`, `edit` |
| `ConditionsJson` | `nvarchar(max)` | JSON array of `{TemplateName, Parameters}` |
| `IsActive` | `bit` | Soft-enable flag |

**Unique indexes:**
- `UX_PolicyDefinitions_Tenant_Resource_Action` — unique on `(TenantId, ResourceType, Action)` where `TenantId IS NOT NULL`
- `UX_PolicyDefinitions_Platform_Resource_Action` — unique on `(ResourceType, Action)` where `TenantId IS NULL`

### Caching

`DbAbacPolicyResolver` caches resolved policies in `IMemoryCache`:
- Tenant key: `abac:{tenantId}:{resourceType}:{action}`
- Platform key: `abac:platform:{resourceType}:{action}`

Cache is invalidated via `IAbacPolicyCache`:
```csharp
_policyCache.Invalidate(tenantId, resourceType, action);      // tenant row changed
_policyCache.InvalidatePlatform(resourceType, action);        // platform row changed
```

Handlers call these after create/update/delete operations.

---

## Authorization Flow in Application Handlers

```csharp
// 1. Load resource
var user = await _unitOfWork.Users.GetByIdAsync(userId, ct);

// 2. Resolve ABAC policy (3-tier)
var policy = await _resolver.ResolveAsync(currentUser.TenantId, "user", "read");

// 3. Evaluate — uses IResourceAuthorizationService internally
await _authService.AuthorizeWithResolvedPolicyAsync(
    policy,
    resourceAttributes,
    currentUser,
    requiredPermission: null,  // null = skip RBAC gate (self-read)
    cancellationToken);
```

`AuthorizeWithResolvedPolicyAsync` throws `ForbiddenException` on deny, which middleware maps to HTTP 403.

---

## Rego Policies

```
policies/
  authz/
    common/
      helpers.rego          # Shared helper rules
      template_abac.rego    # Generic template evaluator (drives DB-backed policies)
      tenant.rego           # same_tenant rule
    auth/
      read-user.rego        # Pilot: user profile read
  tests/
    auth/
      read_user_test.rego
```

Run OPA tests locally:
```bash
opa test policies/ -v
```

---

## Configuration

```json
// appsettings.json
{
  "Opa": {
    "BaseUrl": "http://localhost:8181",
    "Timeout": "00:00:05",
    "FailClosed": true,
    "Enabled": true
  }
}
```

```json
// appsettings.Development.json — disable OPA sidecar requirement
{
  "Opa": { "Enabled": false }
}
```

When `Enabled = false`, `NullOpaPolicyClient` is registered (always allows). **Never disable in production.**

---

## Permissions

| Permission | Purpose |
|-----------|---------|
| `Policy.Read` | List tenant-level ABAC policies (via `GET /api/v1/policy`) |
| `Policy.Write` | Create/update/delete tenant-level policies |
| `Platform.Policy.Read` | List platform-level (global) ABAC policies |
| `Platform.Policy.Write` | Create/update/delete platform-level policies |

All four permissions are seeded to the `Admin` role via EF migrations.
