# P04-S4 — DB8 tenant-query governance

Date: 2026-09-10  
Repository delivery owner: xiaolong-feng (`@von12549`)  
Production RLS / credential evidence: **not run, not claimed**

## Decision

Tenant-owned reads use a non-empty tenant identity from the trusted execution context, pass it through the repository contract, reject `Guid.Empty`, and include the tenant predicate in the database query. Authorization after materialization is an additional control; it is not a substitute for the predicate.

EF global query filters are **not selected** for the current design. The module DbContexts contain mixed tenant, platform-catalog and identity-bootstrap entities and do not own a safe ambient tenant provider. This decision avoids invisible test behavior and an `IgnoreQueryFilters` escape hatch. The machine policy records the conditions for reconsideration.

SQL Server RLS is **deferred-not-claimed**. Adoption requires DB5 credential separation, pool-safe `SESSION_CONTEXT`, an owned break-glass role, performance evidence and production-equivalent isolation tests. No repository evidence here represents deployed RLS.

## Repository adoption

- CRM, Registry, Transaction and Holdings tenant reads call `TenantQueryGuard.Require` and contain an explicit tenant predicate.
- Auth `Role`, `RoleGroup`, `Department`, tenant `PolicyDefinition` and tenant `Idp` point reads now accept the trusted tenant in their contracts and predicates.
- Tenant and platform policy records use separate `GetTenantByIdAsync` / `GetPlatformByIdAsync` entry points.
- Five Auth administration reads use separately named `AcrossTenants` repository methods. They require an authenticated actor, an approved platform role, `Platform.GlobalRole:manage`, a fixed purpose, structured audit fields and a database-side maximum of 500 rows.
- The bypass registry expires on 2026-12-31 and must be reviewed or removed; there is no boolean bypass flag and no `IgnoreQueryFilters` use in `src`.

## Automated proof

`scripts/Test-Plan04TenantQueryPolicy.ps1` scans repository implementations and selected high-risk contracts, validates every registered platform bypass, rejects nullable/default tenant contracts and ordinary bypass flags, and runs five positive/negative fixtures. Unknown or unregistered `AcrossTenants` methods fail closed.

Current machine result: [`phase4-tenant-query-status.json`](phase4-tenant-query-status.json).  
Inventory: [`tenant-query-inventory.json`](tenant-query-inventory.json).  
Policy: [`tenant-query-policy.json`](../../policies/plan04/tenant-query-policy.json).  
Bypass registry: [`tenant-query-bypass-registry.json`](../../policies/plan04/tenant-query-bypass-registry.json).

Validated locally:

- `Test-Plan04TenantQueryPolicy.ps1`: repository passed; production RLS not claimed.
- BuildingBlocks EF Core tests: 20 passed.
- Auth Application tests: 235 passed.
- Auth Infrastructure tests: 58 passed, including different-tenant negative reads.
- ApiHost source graph build: passed; existing package advisories remain warnings.

## Scope boundary

Auth issuer/subject resolution and email verification are identity-bootstrap lookups; `Tenant`, `Permission` and `GlobalRole` are platform catalogs; `User` is a multi-tenant identity with tenant memberships. These classifications do not authorize cross-tenant business-data access. The only current cross-tenant administration reads are the five entries in the bypass registry.
