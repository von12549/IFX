# PolicyDefinition Scope Field Plan

**Date:** 2026-03-26
**Branch:** `feature/abac/scope-globalroles`
**Base:** `feature/complete-abac-policies`
**Status:** Planning

---

## Goal

Replace the `TenantId = NULL` convention for platform-level policies with an explicit `Scope` enum field on `PolicyDefinition`. The scope communicates intent directly — no NULL special-casing, no ambiguity.

---

## Motivation

`TenantId = NULL` is an implicit convention: "if TenantId is null, this is a platform policy." This is fragile — null has many meanings in SQL (unknown, not applicable, not set). An explicit `Scope` field:

- Is self-documenting in schema introspection
- Allows a clean unique index `(Scope, TenantId, ResourceType, Action)`
- Does not require callers to know the NULL convention
- Sets up a clean foundation for the GlobalRole plan (Plan 2) which needs to resolve Platform vs Tenant policies by scope

---

## Scope Values

```csharp
public enum PolicyScope
{
    Tenant = 0,   // Scoped to a specific tenant — TenantId required
    Platform = 1  // Platform-level default — TenantId is NULL (no tenant)
}
```

`TenantId` remains nullable on `PolicyDefinition`. The `Scope` field is the authoritative platform/tenant discriminator; TenantId stays null for Platform rows (database enforcement stays the same, semantics become explicit via Scope).

---

## Affected Areas

### 1. Domain — `PolicyDefinition` entity

**File:** `src/Modules/Auth/IFX.Modules.Auth.Domain/Authorization/PolicyDefinition.cs`

- Add `PolicyScope Scope { get; private set; }` property
- Update `Create()` factory: add `PolicyScope scope` parameter; enforce `TenantId != null` when `scope == Tenant`
- Add invariant: `if (Scope == PolicyScope.Tenant && TenantId == null) throw`

### 2. Application — Commands / Queries

**Create command:** `CreatePolicyCommand` — add `PolicyScope Scope` property; pass to `PolicyDefinition.Create()`

**Platform create command:** `CreatePlatformPolicyCommand` — hardcode `Scope = Platform`, never accept it from caller

**DTOs:** `PolicyDefinitionDto` — add `PolicyScope Scope` for API consumers

**Resolver (`IAbacPolicyResolver` / `AbacPolicyResolver`):**

Current:
```csharp
// Tier 2: platform DB lookup — TenantId IS NULL
await _repo.GetByResourceAndActionAsync(null, resourceType, action, ct)
```
After:
```csharp
// Tier 2: platform DB lookup — Scope = Platform
await _repo.GetPlatformPolicyAsync(resourceType, action, ct)
```

### 3. Infrastructure — Repository

**File:** `src/Modules/Auth/IFX.Modules.Auth.Infrastructure/Persistence/Repositories/PolicyDefinitionRepository.cs`

- Rename or add `GetPlatformPolicyAsync(resourceType, action, ct)` — filters by `Scope = Platform`
- `GetTenantPolicyAsync(tenantId, resourceType, action, ct)` — filters by `Scope = Tenant` and `TenantId = tenantId`
- Remove raw `TenantId IS NULL` filter from existing queries

**Interface:** `IPolicyDefinitionRepository` — update method signatures accordingly

### 4. Infrastructure — EF Core Configuration

**File:** `...Auth.Infrastructure/Persistence/Configurations/PolicyDefinitionConfiguration.cs`

- Map `Scope` as `int` column (EF enum storage): `.HasConversion<int>()`
- Add column to unique index: `.HasIndex(p => new { p.Scope, p.TenantId, p.ResourceType, p.Action }).IsUnique()`
- Remove old `(TenantId, ResourceType, Action)` unique index

### 5. Migration — Add Scope column and backfill

New EF migration: `AddScopeToPolicyDefinition`

```sql
-- Add column with default Tenant
ALTER TABLE auth.PolicyDefinitions ADD Scope INT NOT NULL DEFAULT 0

-- Backfill: rows where TenantId IS NULL are Platform
UPDATE auth.PolicyDefinitions SET Scope = 1 WHERE TenantId IS NULL

-- Drop old unique index, add new one
DROP INDEX IF EXISTS IX_PolicyDefinitions_TenantId_ResourceType_Action ON auth.PolicyDefinitions
CREATE UNIQUE INDEX IX_PolicyDefinitions_Scope_TenantId_ResourceType_Action
    ON auth.PolicyDefinitions (Scope, TenantId, ResourceType, Action)
```

`Down()` reverses: drop new index, recreate old, remove column.

### 6. Existing Seed Migration Update

**File:** `20260325101631_SeedAbacPolicies.cs`

The seed migration inserts with `TenantId = NULL` but does not set `Scope`. After adding the column with `DEFAULT 0` (Tenant), the backfill step in the new migration corrects these rows to `Scope = 1` (Platform).

No change needed to the seed migration itself — order of migrations handles it.

### 7. Tests

Update unit tests that construct `PolicyDefinition` via `PolicyDefinition.Create()`:
- Add `PolicyScope.Tenant` to all existing tenant-policy test usages
- Update `UpdatePolicyCommandHandlerTests`, `CreatePolicyCommandHandlerTests`, etc.
- Add tests for the invariant: `Create(scope: Tenant, tenantId: null)` → throws

---

## Implementation Order

1. `PolicyScope` enum — Domain
2. `PolicyDefinition.Create()` update — Domain
3. `IPolicyDefinitionRepository` interface update — Application
4. `PolicyDefinitionRepository` implementation — Infrastructure
5. `PolicyDefinitionConfiguration` EF update — Infrastructure
6. EF migration `AddScopeToPolicyDefinition`
7. `CreatePolicyCommand` + handler update — Application
8. `CreatePlatformPolicyCommand` + handler update — Application
9. `AbacPolicyResolver` update — Infrastructure
10. DTO update (`PolicyDefinitionDto`)
11. Test updates

---

## What Does NOT Change

- `TenantId` remains nullable — Platform rows still have `TenantId = NULL`
- 3-tier resolution order: tenant DB → platform DB → static fallback
- OPA Rego policy — no change
- All existing seeded policy UUIDs — stable

---

## Open Questions

None. This is a contained refactor with no behavioral change — only explicit semantics replace implicit convention.
