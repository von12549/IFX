# Plan: DB-Backed Tenant-Level ABAC Policies

**Date:** 2026-03-25
**Status:** Draft
**Depends on:** `feature/security/template-abac` (template ABAC engine must be in place)

---

## Goal

Allow tenant administrators to configure ABAC policies at runtime via an admin API, stored in the database and scoped per tenant. Platform-default policies (current static C# classes) serve as fallbacks when no tenant override exists. OPA requires no changes — the generic `abac_eval.rego` evaluator is already static.

---

## Key Insight

`abac_eval.rego` is generic and static — it evaluates whatever conditions appear in `input.conditions`. Policies stored in the DB are **condition data**, not Rego logic. No OPA sync is needed; only the C# resolution layer changes.

```
DB: PolicyDefinition (tenant_id, resource_type, action, conditions[])
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
| What admins can configure | Compose registered ConditionTemplates only — no arbitrary field paths or raw conditions |
| Cache strategy | Short-lived in-memory cache per tenant (configurable TTL, default 60s); or event-driven invalidation |
| AuthorizeWithPolicyAsync signature | Add overload that resolves policy by (tenantId, resourceType, action) from repository |
| Platform defaults | Current static `UserPolicies`, etc. become the default `IPolicyRepository` implementation |

---

## Architecture

### Policy lookup order

```
GetPolicy(tenantId, resourceType, action)
  1. Tenant-specific policy in DB         → use if found
  2. Platform default (static C# class)   → use as fallback
  3. No policy found                       → deny (empty conditions = deny in abac_eval)
```

### Tenant policy customization example

```
Platform default:   ReadDocument = [SameTenant, SameDepartment]
Tenant A override:  ReadDocument = [SameTenant]               ← looser (contractual)
Tenant B override:  ReadDocument = [SameTenant, CreatedByMe]  ← stricter
```

---

## What Needs to Change

### Domain — `IFX.Modules.Auth.Domain`

- `PolicyDefinition` entity
  - `TenantId` (nullable — null = platform default)
  - `ResourceType` (string)
  - `Action` (string)
  - `Conditions` (serialized list of `{ TemplateName, Parameters }`)
  - Audit fields: `CreatedAt`, `UpdatedAt`, `CreatedBy`

### Application — `IFX.Modules.Auth.Application`

- `IPolicyRepository` — `GetAsync(tenantId, resourceType, action)`, `SaveAsync(...)`, `DeleteAsync(...)`
- `IAbacPolicyResolver` (new abstraction in BuildingBlocks) — resolves `AbacPolicy` by `(tenantId, resourceType, action)`; default impl uses static classes, DB impl overrides
- New commands/queries: `CreatePolicyCommand`, `UpdatePolicyCommand`, `DeletePolicyCommand`, `GetPoliciesQuery`
- Validators: template names must exist in `IAbacTemplateRegistry`; conditions list must not be empty

### Infrastructure — `IFX.Modules.Auth.Infrastructure`

- `PolicyRepository` — EF Core implementation of `IPolicyRepository`
- `DbAbacPolicyResolver` — loads from DB with cache; falls back to static defaults
- Cache: `IMemoryCache` with configurable TTL; invalidated on save/delete
- EF migration: `PolicyDefinitions` table

### BuildingBlocks — `IFX.BuildingBlocks.Security`

- `IAbacPolicyResolver` interface — `Task<AbacPolicy?> ResolveAsync(Guid? tenantId, string resourceType, string action)`
- New `AuthorizeWithPolicyAsync` overload on `IResourceAuthorizationService` that accepts `(resourceType, action)` and resolves policy internally via `IAbacPolicyResolver`

### Presentation — `IFX.Modules.Auth.Presentation`

- `GET    /api/v1/policy`         — list policies for selected tenant
- `POST   /api/v1/policy`         — create tenant policy override
- `PUT    /api/v1/policy/{id}`    — update tenant policy override
- `DELETE /api/v1/policy/{id}`    — delete tenant policy override (reverts to platform default)
- All endpoints gated by `policies.manage` permission

---

## Security Constraints

- Admins may only compose registered `ConditionTemplate`s — no arbitrary field paths
- `policies.manage` is a high-privilege permission; assign to platform admins only
- Every policy change is audit-logged (who changed what, when, previous value)
- Consider two-person approval flow for production tenants (future)
- Platform-default policies (null tenantId) are **not** editable via the admin API — code-only

---

## Risks

| Risk | Mitigation |
|---|---|
| Compromised admin account changes policies | Audit log, `policies.manage` strictly controlled, alert on policy change |
| Stale cache after policy update | Short TTL (60s) acceptable for most cases; event-based invalidation if needed |
| Admin creates empty/invalid policy | Validator rejects: empty conditions = deny, unknown template name = reject |
| Multi-instance cache inconsistency | TTL-based expiry handles eventual consistency; or use distributed cache (Redis) |

---

## Out of Scope

- Rego policy storage in DB (not needed — abac_eval.rego is generic)
- Per-user policy customization (tenant-level is the scope)
- OPA partial evaluation for list filtering (separate concern)
- Approval workflow for policy changes (future)
- Frontend policy management UI (follows after API)

---

## Implementation Order

1. Domain: `PolicyDefinition` entity
2. BuildingBlocks: `IAbacPolicyResolver` interface + static default implementation
3. Application: `IPolicyRepository`, commands/queries, validators
4. Infrastructure: `PolicyRepository`, `DbAbacPolicyResolver` with cache, EF migration
5. Presentation: admin endpoints gated by `policies.manage`
6. Wire DI: register `DbAbacPolicyResolver` as `IAbacPolicyResolver`
7. Tests: unit tests for resolver fallback logic, integration tests for CRUD endpoints
