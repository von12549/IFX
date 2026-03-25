# Plan: DB-Backed Tenant-Level ABAC Policies

**Date:** 2026-03-25
**Status:** Implemented (2026-03-25)
**Depends on:** `feature/security/template-abac` (template ABAC engine must be in place)

---

## Goal

Allow tenant administrators to configure ABAC policies at runtime via an admin API, stored in the database and scoped per tenant. Platform-default policies (current static C# classes) serve as fallbacks when no tenant override exists. OPA requires no changes — the generic `abac_eval.rego` evaluator is already static.

---

## Key Insight

`abac_eval.rego` is generic and static — it evaluates whatever conditions appear in `input.conditions`. Policies stored in the DB are **condition data**, not Rego logic. No OPA sync is needed; only the C# resolution layer changes.

```
DB: PolicyDefinition (tenant_id, resource_type, action, name, conditions[])
        ↓
C# engine: loads from DB (cached), resolves conditions → ResolvedCondition[]
        ↓
OPA: abac_eval.rego (static, unchanged) evaluates them
```

---

## Design Decisions

| Question | Decision |
|---|---|
| OPA sync required? | No — abac_eval.rego is already generic; conditions are data, not logic |
| Policy scope | Tenant-level overrides; fall back to platform defaults (static classes) |
| What admins can configure | Compose registered ConditionTemplates only — no arbitrary field paths |
| Cache strategy | In-memory cache per tenant, TTL 60s; invalidated on save/delete |
| Platform defaults | Current static `UserPolicies`, etc. serve as the default resolver fallback |
| Platform defaults editable? | No — null `TenantId` rows are code-only; API rejects `TenantId = null` |
| Unique constraint | One policy per `(TenantId, ResourceType, Action)` tuple |
| Soft delete? | No — hard delete; revert to platform default by deleting the tenant row |
| Conditions storage | JSON column (`nvarchar(max)`) — `PolicyConditionRecord[]` |
| Audit | `CreatedAt`, `UpdatedAt`, `CreatedById`, `UpdatedById` on entity |

---

## Architecture

### Policy lookup order

```
ResolveAsync(tenantId, resourceType, action)
  1. Tenant-specific row in DB         → deserialize → AbacPolicy
  2. Platform default (static class)   → AbacPolicy from code
  3. Nothing found                      → null → deny (empty conditions = deny in abac_eval)
```

### Tenant policy customization example

```
Platform default:   ReadDocument = [SameTenant, SameDepartment]
Tenant A override:  ReadDocument = [SameTenant]               ← looser (contractual)
Tenant B override:  ReadDocument = [SameTenant, CreatedByMe]  ← stricter
```

---

## 1. Database Design

### Table: `PolicyDefinitions`

```sql
CREATE TABLE PolicyDefinitions (
    Id             UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID() PRIMARY KEY,
    TenantId       UNIQUEIDENTIFIER NOT NULL,             -- always a real tenant; platform defaults are code-only
    Name           NVARCHAR(200)    NOT NULL,             -- human-readable label, e.g. "Read Own Profile"
    ResourceType   NVARCHAR(100)    NOT NULL,             -- e.g. "user", "document"
    Action         NVARCHAR(100)    NOT NULL,             -- e.g. "read", "edit", "delete"
    ConditionsJson NVARCHAR(MAX)    NOT NULL,             -- JSON: PolicyConditionRecord[]
    IsActive       BIT              NOT NULL DEFAULT 1,
    CreatedAt      DATETIME2        NOT NULL,
    UpdatedAt      DATETIME2        NOT NULL,
    CreatedById    UNIQUEIDENTIFIER NULL,                 -- FK to Users.Id (nullable for seed data)
    UpdatedById    UNIQUEIDENTIFIER NULL
);

-- Enforce one policy per (tenant, resource, action)
CREATE UNIQUE INDEX UX_PolicyDefinitions_Tenant_Resource_Action
    ON PolicyDefinitions (TenantId, ResourceType, Action);

-- Fast lookup by tenant
CREATE INDEX IX_PolicyDefinitions_TenantId
    ON PolicyDefinitions (TenantId);
```

### JSON column shape: `ConditionsJson`

```json
[
  { "templateName": "SameTenant",     "parameters": null },
  { "templateName": "CreatedByMe",    "parameters": null },
  { "templateName": "AmountBelow",    "parameters": { "maxAmount": 1000 } }
]
```

### EF Core configuration (new file)

`Infrastructure/Authorization/Configurations/PolicyDefinitionConfiguration.cs`

```csharp
builder.ToTable("PolicyDefinitions");
builder.HasKey(p => p.Id);
builder.Property(p => p.Name).HasMaxLength(200).IsRequired();
builder.Property(p => p.ResourceType).HasMaxLength(100).IsRequired();
builder.Property(p => p.Action).HasMaxLength(100).IsRequired();
builder.Property(p => p.ConditionsJson).HasColumnType("nvarchar(max)").IsRequired();
builder.HasIndex(p => new { p.TenantId, p.ResourceType, p.Action }).IsUnique();
builder.HasIndex(p => p.TenantId);
```

### EF Migration

One new migration: `AddPolicyDefinitions`

```bash
dotnet ef migrations add AddPolicyDefinitions --startup-project ../../../ApiHost/IFX.ApiHost
dotnet ef database update --startup-project ../../../ApiHost/IFX.ApiHost
```

---

## 2. Backend Design

### 2a. Domain — `IFX.Modules.Auth.Domain/Authorization/`

**New files:**

`PolicyDefinition.cs`
```csharp
public class PolicyDefinition : BaseEntity, IAuditableEntity
{
    public Guid TenantId { get; private set; }
    public string Name { get; private set; }             // human-readable label, e.g. "Read Own Profile"
    public string ResourceType { get; private set; }
    public string Action { get; private set; }
    public string ConditionsJson { get; private set; }   // serialized PolicyConditionRecord[]
    public bool IsActive { get; private set; }
    public Guid? CreatedById { get; private set; }
    public Guid? UpdatedById { get; private set; }
    public DateTime CreatedAt { get; set; }
    public DateTime UpdatedAt { get; set; }

    private PolicyDefinition() { }   // EF Core

    public static PolicyDefinition Create(Guid tenantId, string name, string resourceType,
        string action, string conditionsJson, Guid? createdById)
    { /* guard + new */ }

    public void Update(string name, string conditionsJson, Guid? updatedById)
    { /* guard + set */ }

    public void Deactivate() => IsActive = false;
}
```

`PolicyConditionRecord.cs` — value object for JSON serialization
```csharp
public sealed record PolicyConditionRecord(
    string TemplateName,
    Dictionary<string, object>? Parameters);
```

`IPolicyDefinitionRepository.cs`
```csharp
public interface IPolicyDefinitionRepository
{
    Task<PolicyDefinition?> GetAsync(Guid tenantId, string resourceType,
        string action, CancellationToken ct = default);
    Task<List<PolicyDefinition>> GetByTenantIdAsync(Guid tenantId,
        CancellationToken ct = default);
    Task AddAsync(PolicyDefinition policy, CancellationToken ct = default);
    void Remove(PolicyDefinition policy);
    Task<bool> ExistsAsync(Guid tenantId, string resourceType,
        string action, CancellationToken ct = default);
}
```

---

### 2b. BuildingBlocks — `IFX.BuildingBlocks.Security/Authorization/Abac/`

**New interface:** `Resolver/IAbacPolicyResolver.cs`
```csharp
public interface IAbacPolicyResolver
{
    Task<AbacPolicy?> ResolveAsync(Guid? tenantId, string resourceType,
        string action, CancellationToken ct = default);
}
```

**New overload on `IResourceAuthorizationService`:**
```csharp
// Resolves the policy by (tenantId, resourceType, action) via IAbacPolicyResolver.
// Falls back to platform default if no tenant override exists.
Task AuthorizeAsync<TResource>(
    string resourceType,
    string action,
    TResource resourceAttributes,
    CancellationToken ct = default)
    where TResource : OpaResourceAttributesBase;
```

**`ResourceAuthorizationService`** — implement new overload:
```csharp
public async Task AuthorizeAsync<TResource>(
    string resourceType, string action,
    TResource resourceAttributes, CancellationToken ct = default)
{
    var policy = await _policyResolver.ResolveAsync(
        _currentUser.TenantId, resourceType, action, ct)
        ?? throw new ForbiddenException("No policy defined for this action.");

    await AuthorizeWithPolicyAsync(policy, resourceAttributes, ct: ct);
}
```

---

### 2c. Application — `IFX.Modules.Auth.Application/Authorization/Policies/`

**DTOs:**

`PolicyDefinitionDto.cs`
```csharp
public record PolicyDefinitionDto(
    Guid Id,
    Guid TenantId,
    string Name,               // human-readable label
    string ResourceType,
    string Action,
    List<PolicyConditionDto> Conditions,
    bool IsActive,
    bool IsPlatformDefault,    // true if no tenant row exists (frontend shows as read-only)
    DateTime UpdatedAt);

public record PolicyConditionDto(
    string TemplateName,
    Dictionary<string, object>? Parameters);
```

**Commands and Queries:**

| File | Type | Description |
|---|---|---|
| `CreatePolicyCommand.cs` | Command | `(TenantId, Name, ResourceType, Action, Conditions[])` |
| `UpdatePolicyCommand.cs` | Command | `(PolicyId, Name, Conditions[])` |
| `DeletePolicyCommand.cs` | Command | `(PolicyId)` — hard delete, reverts to platform default |
| `GetPoliciesQuery.cs` | Query | `(TenantId)` — returns tenant rows + platform defaults merged |
| `GetAvailableTemplatesQuery.cs` | Query | Returns all registered template names (for condition builder UI) |

**Validators (FluentValidation):**

`CreatePolicyCommandValidator.cs`
- `TenantId` must not be empty
- `Name` must not be empty, max 200 chars
- `ResourceType` and `Action` must not be empty, max 100 chars
- `Conditions` must have at least one entry
- Each `TemplateName` must exist in `IAbacTemplateRegistry`
- `PolicyDefinitionRepository.ExistsAsync` must return false (no duplicate)

**Handlers resolve `IAbacTemplateRegistry`** to validate template names before saving.

---

### 2d. Infrastructure — `IFX.Modules.Auth.Infrastructure/Authorization/`

**`PolicyDefinitionRepository.cs`** — EF Core implementation of `IPolicyDefinitionRepository`

**`DbAbacPolicyResolver.cs`**
```csharp
public class DbAbacPolicyResolver : IAbacPolicyResolver
{
    // 1. Try DB (with IMemoryCache, TTL 60s, key = "policy:{tenantId}:{resourceType}:{action}")
    // 2. Deserialize ConditionsJson → PolicyConditionRecord[]
    // 3. Resolve each TemplateName via IAbacTemplateRegistry → AbacCondition[]
    // 4. Return AbacPolicy; on cache miss or not found, fall back to StaticAbacPolicyResolver

    // Cache is invalidated in CreatePolicyCommandHandler and UpdatePolicyCommandHandler
    // by calling _cache.Remove(cacheKey) after SaveChangesAsync
}
```

**`StaticAbacPolicyResolver.cs`** — fallback, reads from registered static dictionaries
```csharp
// Modules register their defaults at DI setup:
// resolver.Register("user", "read", UserPolicies.ReadOwnProfile);
```

**DI registration** in `DependencyInjection.cs`:
```csharp
services.AddScoped<IPolicyDefinitionRepository, PolicyDefinitionRepository>();
services.AddSingleton<StaticAbacPolicyResolver>(sp => {
    var r = new StaticAbacPolicyResolver();
    r.Register("user", "read", UserPolicies.ReadOwnProfile);
    return r;
});
services.AddScoped<IAbacPolicyResolver, DbAbacPolicyResolver>();
```

**`UnitOfWork`** — add `IPolicyDefinitionRepository PolicyDefinitions` property.

---

### 2e. Presentation — `IFX.Modules.Auth.Presentation/Authorization/`

**Endpoints** (all require `policies.manage` permission; tenant from `X-Tenant-Id` header):

| Method | Route | Handler |
|---|---|---|
| `GET` | `/api/v1/policy` | `GetPoliciesQuery` — merged list (tenant overrides + platform defaults) |
| `GET` | `/api/v1/policy/templates` | `GetAvailableTemplatesQuery` — template names for condition builder |
| `POST` | `/api/v1/policy` | `CreatePolicyCommand` |
| `PUT` | `/api/v1/policy/{id}` | `UpdatePolicyCommand` |
| `DELETE` | `/api/v1/policy/{id}` | `DeletePolicyCommand` — revert to platform default |

**Response shape for `GET /api/v1/policy`:**
```json
{
  "data": [
    {
      "id": "...",
      "name": "Read Own Profile",
      "resourceType": "user",
      "action": "read",
      "conditions": [{ "templateName": "SameTenant" }, { "templateName": "CreatedByMe" }],
      "isActive": true,
      "isPlatformDefault": false,
      "updatedAt": "2026-03-25T10:00:00Z"
    },
    {
      "id": null,
      "name": "Read Document (Platform Default)",
      "resourceType": "document",
      "action": "read",
      "conditions": [{ "templateName": "SameTenant" }, { "templateName": "SameDepartment" }],
      "isActive": true,
      "isPlatformDefault": true    ← no DB row; showing platform default as read-only
    }
  ]
}
```

**Response shape for `GET /api/v1/policy/templates`:**
```json
{
  "data": [
    { "name": "SameTenant",     "description": "Subject and resource must belong to the same tenant" },
    { "name": "CreatedByMe",    "description": "Subject must be the owner of the resource" },
    { "name": "SameDepartment", "description": "Subject and resource must share at least one department" }
  ]
}
```

---

## 3. Frontend Design

### New files

| File | Purpose |
|---|---|
| `src/api/policy.ts` | API client for policy endpoints |
| `src/pages/PolicyManagementPage.tsx` | Main management page |
| `src/pages/__tests__/PolicyManagementPage.test.tsx` | Vitest tests |

### `src/api/policy.ts`

```typescript
import { apiClient } from './client'
import type { PolicyDefinitionDto, CreatePolicyRequest, UpdatePolicyRequest, TemplateDto } from '../types/api'

export const policyApi = {
  getAll: () =>
    apiClient.get<{ data: PolicyDefinitionDto[] }>('/api/v1/policy'),

  getTemplates: () =>
    apiClient.get<{ data: TemplateDto[] }>('/api/v1/policy/templates'),

  create: (data: CreatePolicyRequest) =>
    apiClient.post('/api/v1/policy', data),

  update: (id: string, data: UpdatePolicyRequest) =>
    apiClient.put(`/api/v1/policy/${id}`, data),

  delete: (id: string) =>
    apiClient.delete(`/api/v1/policy/${id}`),
}
```

### TypeScript types (add to `src/types/api.ts`)

```typescript
export interface PolicyConditionDto {
  templateName: string
  parameters?: Record<string, unknown> | null
}

export interface PolicyDefinitionDto {
  id: string | null               // null when isPlatformDefault = true
  name: string                    // human-readable label
  resourceType: string
  action: string
  conditions: PolicyConditionDto[]
  isActive: boolean
  isPlatformDefault: boolean
  updatedAt: string
}

export interface TemplateDto {
  name: string
  description: string
}

export interface CreatePolicyRequest {
  name: string
  resourceType: string
  action: string
  conditions: PolicyConditionDto[]
}

export interface UpdatePolicyRequest {
  name: string
  conditions: PolicyConditionDto[]
}
```

### `PolicyManagementPage.tsx` — UI behaviour

- **Load on mount / tenant change:** `policyApi.getAll()` + `policyApi.getTemplates()`
- **Table columns:** Name, Resource Type, Action, Conditions (chips), Source (Tenant Override / Platform Default), Actions
- **Platform default rows:** shown with a badge "Platform Default", no Delete button, Override button opens create modal pre-filled with `resourceType` and `action` (Name field blank for the admin to fill)
- **Tenant override rows:** Edit and Delete (revert) buttons
- **Create/Edit modal:**
  - Name input (text, required) — e.g. "Read Own Profile"
  - ResourceType input (text)
  - Action input (text)
  - Condition builder: multi-select of available templates; each selected template shows a parameter form if the template has `parameters`
- **Delete confirmation:** "This will revert to the platform default policy for {name} ({resourceType}/{action})"

### Router

Add to `src/App.tsx` routes:
```tsx
<Route path="/policies" element={<PolicyManagementPage />} />
```

Add to sidebar navigation (alongside Roles, Permissions):
```tsx
{ label: 'Policies', path: '/policies', permission: 'policies.manage' }
```

---

## 4. Test Plan

### 4a. Unit Tests — `IFX.Modules.Auth.Application.Tests`

**`DbAbacPolicyResolverTests.cs`**
- Returns tenant override when DB row exists
- Falls back to platform default when no DB row
- Returns null when neither DB row nor platform default exists
- Cache hit avoids second DB call (verify repository called once for two resolver calls)
- Cache is invalidated after create (next resolve hits DB again)
- Cache is invalidated after update

**`CreatePolicyCommandHandlerTests.cs`**
- Creates policy when valid input and no duplicate
- Returns failure when template name not registered in `IAbacTemplateRegistry`
- Returns failure when conditions list is empty
- Returns failure when duplicate `(TenantId, ResourceType, Action)` already exists

**`UpdatePolicyCommandHandlerTests.cs`**
- Updates conditions when policy found
- Returns failure when policy not found
- Returns failure when updated conditions contain unknown template name

**`DeletePolicyCommandHandlerTests.cs`**
- Removes policy when found
- Returns failure when policy not found

**`GetPoliciesQueryHandlerTests.cs`**
- Returns tenant rows merged with platform defaults
- Platform default marked with `IsPlatformDefault = true` and `Id = null`
- Tenant override replaces platform default for same `(resourceType, action)`

**`CreatePolicyCommandValidatorTests.cs`**
- Rejects empty `Name`
- Rejects `Name` exceeding 200 characters
- Rejects empty `ResourceType` / `Action`
- Rejects empty conditions list
- Rejects unknown template name

---

### 4b. Integration Tests — `IFX.IntegrationTests`

**`PolicyEndpointsTests.cs`**
- `GET /api/v1/policy` returns merged list for selected tenant
- `GET /api/v1/policy/templates` returns registered templates
- `POST /api/v1/policy` creates override; subsequent GET shows new row with correct `name`
- `PUT /api/v1/policy/{id}` updates name and conditions; subsequent GET reflects change
- `DELETE /api/v1/policy/{id}` removes override; subsequent GET shows platform default
- `POST` with unknown template name returns 400
- `POST` duplicate `(resourceType, action)` returns 409
- All endpoints return 403 when caller lacks `policies.manage` permission

---

### 4c. Frontend Tests — `PolicyManagementPage.test.tsx`

- Renders policy table with Name, Resource Type, Action columns
- Platform default rows show "Platform Default" badge and their name, no Delete button
- Tenant override rows show Edit and Delete buttons
- Clicking Override on a platform default opens create modal pre-filled with resourceType/action
- Create modal validates empty conditions (submit disabled)
- Delete shows confirmation dialog with revert message
- Reload triggered after create / update / delete
- Reload triggered when `selectedTenantId` changes

---

## Security Constraints

- Admins may only compose registered `ConditionTemplate`s — no arbitrary field paths
- `policies.manage` is a high-privilege permission; assign to platform admins only
- Every policy change captures `CreatedById` / `UpdatedById` from `ICurrentUser`
- Platform-default policies (`TenantId = null`) are **not** editable via the admin API
- API rejects any request where the `TenantId` in the body differs from `X-Tenant-Id` header

---

## Risks

| Risk | Mitigation |
|---|---|
| Compromised admin changes policies | Audit fields on entity; `policies.manage` strictly controlled |
| Stale cache after policy update | Explicit cache invalidation in command handlers; TTL as safety net |
| Admin creates empty/invalid policy | Validator rejects: empty conditions, unknown template names |
| Multi-instance cache inconsistency | TTL (60s) handles eventual consistency; upgrade to Redis if needed |
| DB conditions JSON corrupt/unreadable | Deserialise in resolver with try/catch; fall back to platform default + alert |

---

## Out of Scope

- Rego policy storage in DB (not needed — abac_eval.rego is generic)
- Per-user policy customization (tenant-level is the scope)
- OPA partial evaluation for list filtering (separate concern)
- Approval workflow for policy changes
- Policy change history / full audit log table (future)

---

## Implementation Order

1. **Domain** — `PolicyDefinition`, `PolicyConditionRecord`, `IPolicyDefinitionRepository`
2. **BuildingBlocks** — `IAbacPolicyResolver`, `StaticAbacPolicyResolver`, new `AuthorizeAsync` overload
3. **Infrastructure** — `PolicyDefinitionRepository`, `DbAbacPolicyResolver`, EF config, migration, DI wiring
4. **Application** — DTOs, commands, queries, handlers, validators
5. **Presentation** — endpoints, permission seed (`policies.manage`)
6. **Frontend** — `policy.ts` API client, types, `PolicyManagementPage.tsx`, router + nav entry
7. **Tests** — unit (resolver, handlers, validators), integration (endpoints), frontend (page)
