# Plan: Merge EF Migrations + UUID v7 Seed IDs

**Date:** 2026-03-27
**Branch:** `feature/merge-ef-migrations-v7`
**Status:** Planned
**Base:** `main`
**Scope:** `IFX.Modules.Auth.Infrastructure` — `Persistence/Migrations/`

**Goals:**
1. Squash all 10 current migrations (5 schema + 5 seed) into 2 clean migrations: `InitialCreate` (schema) + `InitialSeed` (all seed data)
2. Replace every non-UUID-v7 GUID in `InitialSeed` with a proper UUID v7 value under a consistent naming scheme
3. Standardise the manually-constructed v7 IDs in `SeedGlobalRoles` and `SeedGlobalRolePlatformPolicies` to the same scheme

---

## Current State — 10 Migrations

### Schema migrations (5)

| File | What It Does |
|------|---|
| `20260325055236_InitialCreate` | Creates all tables, indexes (base schema) |
| `20260325095303_AddCreatedByToResources` | Adds `CreatedBy` (Guid? nullable) to Users, UserIdentities, Tenants, Roles, RoleGroups, Idps, Departments; backfills with admin user ID |
| `20260325155638_AddScopeToPolicyDefinition` | Drops `UX_PolicyDefinitions_Tenant_Resource_Action`; adds `Scope int default 0`; adds `UX_PolicyDefinitions_Scope_Tenant_Resource_Action` (filtered TenantId IS NOT NULL) |
| `20260325184645_AddGlobalRoles` | Creates `GlobalRoles` + `UserGlobalRoles` tables and indexes |
| `20260326094436_FixPlatformPolicyUniqueIndex` | Drops `UX_PolicyDefinitions_Platform_Resource_Action` and `IX_PolicyDefinitions_Scope_TenantId_ResourceType_Action` (IF EXISTS — used to clean up a transitional index) |

### Seed migrations (5)

| File | What It Seeds |
|------|---|
| `20260325055258_InitialSeed` | Tenant, Department, IdPs, Permissions (45), Roles (4), RoleGroup, RoleGroupRoles, RolePermissions, Admin user + identity, UserRoles/Groups/Tenants/Departments, 2 PolicyDefinitions |
| `20260325101631_SeedAbacPolicies` | 31 platform-level PolicyDefinitions (UUID v7 already ✓) |
| `20260325184706_SeedGlobalRoles` | 3 GlobalRoles (PlatformAdmin/Support/Auditor) |
| `20260326094516_SeedGlobalRolePlatformPolicies` | 21 platform PolicyDefinitions for PlatformSupport + PlatformAuditor |
| `20260326095802_SeedPlatformAdminUser` | UserGlobalRole: admin user → PlatformAdmin |

---

## UUID v7 Audit

UUID v7 format: `tttttttt-tttt-7rrr-vrrr-rrrrrrrrrrrr`
- Bits 0–47: Unix ms timestamp (big-endian)
- Bits 48–51: version = `7`
- Bits 52–63: random (rand_a)
- Bits 64–65: variant = `10` (so the v octet is 8–B hex)
- Bits 66–127: random (rand_b)

### IDs that are NOT UUID v7 (version nibble ≠ 7)

All in `InitialSeed`:

| Constant | Current value | Problem |
|---|---|---|
| `IFXTenantId` | `AAAAAAAA-0001-0000-…` | version nibble = 0 |
| `TestDeptId` | `AAAAAAAA-0002-0000-…` | version nibble = 0 |
| `IdpIfxCognitoId` | `B1B2C3D4-0002-0000-…` | version nibble = 0 |
| `IdpTestExternalId` | `B1B2C3D4-0002-0000-…-002` | version nibble = 0 |
| `IdpVonCognitoId` | `B1B2C3D4-0002-0000-…-003` | version nibble = 0 |
| `RoleAdminId` | `D0000000-0001-0000-…` | version nibble = 0 |
| `RoleUserId` | `D0000000-0001-0000-…-002` | version nibble = 0 |
| `RoleSsoUserId` | `D0000000-0001-0000-…-003` | version nibble = 0 |
| `RolePendingId` | `D0000000-0001-0000-…-004` | version nibble = 0 |
| `RoleGroupTestId` | `D0000000-0002-0000-…` | version nibble = 0 |
| `PermUserList` … `PermPlatformPolicyDelete` (45) | `E0000000-0000-0000-…` | version nibble = 0 |
| `AdminUserId` | `8314F7DA-2F5D-4128-…` | version nibble = 1 (UUID v1-like) |
| `AdminUserIdentityId` | `294B1D4A-6E22-4BE2-…` | version nibble = 4 |
| PolicyDefinition IDs (2) | `NEWID()` at runtime | not stable |

### IDs technically valid UUID v7 but inconsistent scheme

| Migration | IDs | Note |
|---|---|---|
| `SeedGlobalRoles` | `0195d1a0-0000-7000-8000-00000000000{1,2,3}` | manually constructed |
| `SeedGlobalRolePlatformPolicies` | `019D8000-{0001,0002}-7000-8000-…` | manually constructed |

These will be replaced to match the uniform scheme below.

---

## New UUID v7 Scheme

**Base timestamp:** `2026-01-01T00:00:00.000Z` = `1,767,225,600,000` ms = `0x019B76DAA800`

Format: `019B76DA-A800-7{group:03X}-8000-{seq:012X}`

Where `{group}` identifies the entity type and `{seq}` is a 1-based counter within that group.

> **Why this scheme?** Fixed timestamp + sequential group/seq makes IDs human-readable, self-documenting, and trivially unique. The variant byte `80` satisfies RFC 4122 (top 2 bits = `10`).

### Full ID Mapping

#### Group 001 — Tenants

| Constant | New UUID v7 |
|---|---|
| `IFXTenantId` | `019B76DA-A800-7001-8000-000000000001` |

#### Group 002 — Departments

| Constant | New UUID v7 |
|---|---|
| `TestDeptId` | `019B76DA-A800-7002-8000-000000000001` |

#### Group 003 — IdPs

| Constant | New UUID v7 |
|---|---|
| `IdpIfxCognitoId` | `019B76DA-A800-7003-8000-000000000001` |
| `IdpTestExternalId` | `019B76DA-A800-7003-8000-000000000002` |
| `IdpVonCognitoId` | `019B76DA-A800-7003-8000-000000000003` |

#### Group 004 — Roles

| Constant | New UUID v7 |
|---|---|
| `RoleAdminId` | `019B76DA-A800-7004-8000-000000000001` |
| `RoleUserId` | `019B76DA-A800-7004-8000-000000000002` |
| `RoleSsoUserId` | `019B76DA-A800-7004-8000-000000000003` |
| `RolePendingId` | `019B76DA-A800-7004-8000-000000000004` |

#### Group 005 — RoleGroups

| Constant | New UUID v7 |
|---|---|
| `RoleGroupTestId` | `019B76DA-A800-7005-8000-000000000001` |

#### Group 006 — Permissions (45 entries)

| Constant | New UUID v7 |
|---|---|
| `PermUserList` | `019B76DA-A800-7006-8000-000000000001` |
| `PermUserRead` | `019B76DA-A800-7006-8000-000000000002` |
| `PermUserCreate` | `019B76DA-A800-7006-8000-000000000003` |
| `PermUserUpdate` | `019B76DA-A800-7006-8000-000000000004` |
| `PermUserDelete` | `019B76DA-A800-7006-8000-000000000005` |
| `PermRoleList` | `019B76DA-A800-7006-8000-000000000006` |
| `PermRoleRead` | `019B76DA-A800-7006-8000-000000000007` |
| `PermRoleCreate` | `019B76DA-A800-7006-8000-000000000008` |
| `PermRoleUpdate` | `019B76DA-A800-7006-8000-000000000009` |
| `PermRoleDelete` | `019B76DA-A800-7006-8000-00000000000A` |
| `PermRoleGroupList` | `019B76DA-A800-7006-8000-00000000000B` |
| `PermRoleGroupRead` | `019B76DA-A800-7006-8000-00000000000C` |
| `PermRoleGroupCreate` | `019B76DA-A800-7006-8000-00000000000D` |
| `PermRoleGroupUpdate` | `019B76DA-A800-7006-8000-00000000000E` |
| `PermRoleGroupDelete` | `019B76DA-A800-7006-8000-00000000000F` |
| `PermPermissionList` | `019B76DA-A800-7006-8000-000000000010` |
| `PermPermissionRead` | `019B76DA-A800-7006-8000-000000000011` |
| `PermPermissionCreate` | `019B76DA-A800-7006-8000-000000000012` |
| `PermPermissionUpdate` | `019B76DA-A800-7006-8000-000000000013` |
| `PermPermissionDelete` | `019B76DA-A800-7006-8000-000000000014` |
| `PermIdpList` | `019B76DA-A800-7006-8000-000000000015` |
| `PermIdpRead` | `019B76DA-A800-7006-8000-000000000016` |
| `PermIdpCreate` | `019B76DA-A800-7006-8000-000000000017` |
| `PermIdpUpdate` | `019B76DA-A800-7006-8000-000000000018` |
| `PermIdpDelete` | `019B76DA-A800-7006-8000-000000000019` |
| `PermDepartmentList` | `019B76DA-A800-7006-8000-00000000001A` |
| `PermDepartmentRead` | `019B76DA-A800-7006-8000-00000000001B` |
| `PermDepartmentCreate` | `019B76DA-A800-7006-8000-00000000001C` |
| `PermDepartmentUpdate` | `019B76DA-A800-7006-8000-00000000001D` |
| `PermDepartmentDelete` | `019B76DA-A800-7006-8000-00000000001E` |
| `PermTenantList` | `019B76DA-A800-7006-8000-00000000001F` |
| `PermTenantRead` | `019B76DA-A800-7006-8000-000000000020` |
| `PermTenantCreate` | `019B76DA-A800-7006-8000-000000000021` |
| `PermTenantUpdate` | `019B76DA-A800-7006-8000-000000000022` |
| `PermTenantDelete` | `019B76DA-A800-7006-8000-000000000023` |
| `PermPolicyList` | `019B76DA-A800-7006-8000-000000000024` |
| `PermPolicyRead` | `019B76DA-A800-7006-8000-000000000025` |
| `PermPolicyCreate` | `019B76DA-A800-7006-8000-000000000026` |
| `PermPolicyUpdate` | `019B76DA-A800-7006-8000-000000000027` |
| `PermPolicyDelete` | `019B76DA-A800-7006-8000-000000000028` |
| `PermPlatformPolicyList` | `019B76DA-A800-7006-8000-000000000029` |
| `PermPlatformPolicyRead` | `019B76DA-A800-7006-8000-00000000002A` |
| `PermPlatformPolicyCreate` | `019B76DA-A800-7006-8000-00000000002B` |
| `PermPlatformPolicyUpdate` | `019B76DA-A800-7006-8000-00000000002C` |
| `PermPlatformPolicyDelete` | `019B76DA-A800-7006-8000-00000000002D` |

#### Group 007 — Users

| Constant | New UUID v7 |
|---|---|
| `AdminUserId` | `019B76DA-A800-7007-8000-000000000001` |

#### Group 008 — UserIdentities

| Constant | New UUID v7 |
|---|---|
| `AdminUserIdentityId` | `019B76DA-A800-7008-8000-000000000001` |

#### Group 009 — PolicyDefinitions (base, from InitialSeed)

| Constant | New UUID v7 |
|---|---|
| `PolicyUserReadIFX` (IFX tenant, user/read) | `019B76DA-A800-7009-8000-000000000001` |
| `PolicyUserReadPlatform` (platform default, user/read) | `019B76DA-A800-7009-8000-000000000002` |

#### Group 00A — GlobalRoles (replaces 0195d1a0 scheme)

| Constant | New UUID v7 |
|---|---|
| `PlatformAdminId` | `019B76DA-A800-700A-8000-000000000001` |
| `PlatformSupportId` | `019B76DA-A800-700A-8000-000000000002` |
| `PlatformAuditorId` | `019B76DA-A800-700A-8000-000000000003` |

#### Group 00B — PlatformSupport PolicyDefinitions (replaces 019D8000-0001 scheme)

| Constant | New UUID v7 |
|---|---|
| `PSup_UserList` | `019B76DA-A800-700B-8000-000000000001` |
| `PSup_UserRead` | `019B76DA-A800-700B-8000-000000000002` |
| `PSup_RoleList` | `019B76DA-A800-700B-8000-000000000003` |
| `PSup_RoleRead` | `019B76DA-A800-700B-8000-000000000004` |
| `PSup_RoleGroupList` | `019B76DA-A800-700B-8000-000000000005` |
| `PSup_RoleGroupRead` | `019B76DA-A800-700B-8000-000000000006` |
| `PSup_DepartmentList` | `019B76DA-A800-700B-8000-000000000007` |
| `PSup_DepartmentRead` | `019B76DA-A800-700B-8000-000000000008` |
| `PSup_IdpList` | `019B76DA-A800-700B-8000-000000000009` |
| `PSup_IdpRead` | `019B76DA-A800-700B-8000-00000000000A` |
| `PSup_PolicyList` | `019B76DA-A800-700B-8000-00000000000B` |
| `PSup_PolicyRead` | `019B76DA-A800-700B-8000-00000000000C` |
| `PSup_PlatformPolicyList` | `019B76DA-A800-700B-8000-00000000000D` |
| `PSup_PlatformPolicyRead` | `019B76DA-A800-700B-8000-00000000000E` |

#### Group 00C — PlatformAuditor PolicyDefinitions (replaces 019D8000-0002 scheme)

| Constant | New UUID v7 |
|---|---|
| `PAud_UserList` | `019B76DA-A800-700C-8000-000000000001` |
| `PAud_RoleList` | `019B76DA-A800-700C-8000-000000000002` |
| `PAud_RoleGroupList` | `019B76DA-A800-700C-8000-000000000003` |
| `PAud_DepartmentList` | `019B76DA-A800-700C-8000-000000000004` |
| `PAud_IdpList` | `019B76DA-A800-700C-8000-000000000005` |
| `PAud_PolicyList` | `019B76DA-A800-700C-8000-000000000006` |
| `PAud_PlatformPolicyList` | `019B76DA-A800-700C-8000-000000000007` |

> **SeedAbacPolicies IDs (Group 00D+):** The 31 `PolicyXxx` constants in `SeedAbacPolicies` are already proper UUID v7 (generated with `Uuid.NewSequential()`). They are **kept as-is** in the merged seed — do not regenerate.

---

## Target State — 2 Migrations

### Final schema (merged InitialCreate)

All schema changes from 5 migrations absorbed into one:

- Adds `CreatedBy` (Guid nullable) directly to table definitions:
  - `Users`, `UserIdentities`, `Tenants`, `Roles`, `RoleGroups`, `Idps`, `Departments`
- `PolicyDefinitions` includes `Scope int NOT NULL default 0` from creation
- Unique index: `UX_PolicyDefinitions_Scope_Tenant_Resource_Action` (replaces the old name from InitialCreate; filtered on TenantId IS NOT NULL) — this is the final index name from `AddScopeToPolicyDefinition`
- `GlobalRoles` and `UserGlobalRoles` tables included from creation
- The two IF-EXISTS drops in `FixPlatformPolicyUniqueIndex` are omitted — those index names never exist in a fresh single-migration install

**Tables in final schema (21 tables + 2 junction for GlobalRoles):**

`auth` schema — LoginEvents, LogoutEvents, Permissions, PolicyDefinitions, RegistrationFlowEvents, Tenants, UserActivityLogs, Departments, Idps, RoleGroups, Roles, Users, RoleGroupRoles, RolePermissions, UserDepartments, UserIdentities, UserRoleGroups, UserRoles, UserTenants, EmailVerificationTokens, GlobalRoles, UserGlobalRoles

### Merged InitialSeed

Combines all 5 seed migrations into one, in dependency order:

1. Tenant (IFX)
2. Department (Test)
3. IdPs (3)
4. Permissions (45)
5. Roles (4)
6. RoleGroup (TestGroup)
7. RoleGroupRoles
8. RolePermissions
9. Admin User (with `CreatedBy = Id` per self-created rule)
10. Admin UserIdentity (with `CreatedBy = UserId`)
11. Non-user resource backfill for `CreatedBy` → AdminUserId (done inline in INSERTs, no UPDATE needed)
12. UserRoles / UserRoleGroups / UserTenants / UserDepartments
13. PolicyDefinitions — base policies (user/read, IFX tenant + platform default), with stable IDs
14. PolicyDefinitions — ABAC platform defaults (31 rows, SeedAbacPolicies IDs kept unchanged)
15. GlobalRoles (3)
16. PolicyDefinitions — PlatformSupport (14) + PlatformAuditor (7)
17. UserGlobalRoles — Admin → PlatformAdmin

---

## Implementation Steps

### Step 1 — Create Feature Branch

```bash
git checkout main
git pull
git checkout -b feature/merge-ef-migrations-v7
```

### Step 2 — Search for Old GUID References

Before touching any files, grep for all old seed GUIDs so nothing is missed:

```bash
# Old AdminUserId (the most widely referenced)
grep -ri "8314F7DA-2F5D-4128-A705-957CE0C3972E" src/
# Old AdminUserIdentityId
grep -ri "294B1D4A-6E22-4BE2-845B-F5852F9165C8" src/
# Old IFXTenantId
grep -ri "AAAAAAAA-0001-0000-0000-000000000001" src/
# Old role IDs
grep -ri "D0000000-0001-0000-0000-00000000000[1-4]" src/
# Old GlobalRole IDs
grep -ri "0195d1a0-0000-7000-8000-00000000000[1-3]" src/
```

Record all files that need updating alongside the migration files.

### Step 3 — Delete All 10 Migration Files

```
Persistence/Migrations/20260325055236_InitialCreate.cs
Persistence/Migrations/20260325055236_InitialCreate.Designer.cs
Persistence/Migrations/20260325055258_InitialSeed.cs
Persistence/Migrations/20260325055258_InitialSeed.Designer.cs
Persistence/Migrations/20260325095303_AddCreatedByToResources.cs
Persistence/Migrations/20260325095303_AddCreatedByToResources.Designer.cs
Persistence/Migrations/20260325101631_SeedAbacPolicies.cs
Persistence/Migrations/20260325101631_SeedAbacPolicies.Designer.cs
Persistence/Migrations/20260325155638_AddScopeToPolicyDefinition.cs
Persistence/Migrations/20260325155638_AddScopeToPolicyDefinition.Designer.cs
Persistence/Migrations/20260325184645_AddGlobalRoles.cs
Persistence/Migrations/20260325184645_AddGlobalRoles.Designer.cs
Persistence/Migrations/20260325184706_SeedGlobalRoles.cs
Persistence/Migrations/20260325184706_SeedGlobalRoles.Designer.cs
Persistence/Migrations/20260326094436_FixPlatformPolicyUniqueIndex.cs
Persistence/Migrations/20260326094436_FixPlatformPolicyUniqueIndex.Designer.cs
Persistence/Migrations/20260326094516_SeedGlobalRolePlatformPolicies.cs
Persistence/Migrations/20260326094516_SeedGlobalRolePlatformPolicies.Designer.cs
Persistence/Migrations/20260326095802_SeedPlatformAdminUser.cs
Persistence/Migrations/20260326095802_SeedPlatformAdminUser.Designer.cs
Persistence/Migrations/IfxDbContextModelSnapshot.cs   ← regenerated in next step
```

### Step 4 — Generate New InitialCreate (Schema Only)

```bash
cd src/Modules/Auth/IFX.Modules.Auth.Infrastructure
dotnet ef migrations add InitialCreate \
  --startup-project ../../../ApiHost/IFX.ApiHost \
  --context IfxDbContext
```

**Verify the generated migration:**
- Creates `auth` schema
- All 22 tables present in correct FK dependency order
- `PolicyDefinitions` has `Scope int NOT NULL default 0`
- `CreatedBy` column present on the 7 resource tables
- `GlobalRoles` + `UserGlobalRoles` tables present
- Index name is `UX_PolicyDefinitions_Scope_Tenant_Resource_Action` (filtered TenantId IS NOT NULL)
- No `FixPlatformPolicyUniqueIndex` drop statements

> ⚠️ The EF tooling will generate this correctly from the entity configuration — no manual edits to the schema migration needed.

### Step 5 — Write Merged InitialSeed Migration

Create a **new** empty migration:

```bash
dotnet ef migrations add InitialSeed \
  --startup-project ../../../ApiHost/IFX.ApiHost \
  --context IfxDbContext
```

Then replace the generated `Up()` / `Down()` bodies with the combined seed from all 5 seed migrations, applying the new UUID v7 constants from the mapping table above.

**Key differences from the original InitialSeed:**

1. `AdminUserId` → `019B76DA-A800-7007-8000-000000000001`
2. `AdminUserIdentityId` → `019B76DA-A800-7008-8000-000000000001`
3. All `IFXTenantId`, `TestDeptId`, `IdpXxx`, `RoleXxx`, `PermXxx` constants updated per the mapping table
4. `CreatedBy` included directly in each INSERT (no separate backfill UPDATE step)
5. PolicyDefinition IDs for the two base policies are stable (`019B76DA-A800-7009-8000-00000000000{1,2}`) — no more `NEWID()`
6. `SeedAbacPolicies` PolicyXxx constants carried forward unchanged
7. GlobalRole IDs updated to Group 00A scheme
8. PlatformPolicy IDs updated to Group 00B/00C scheme

**Insertion order for `Up()`:**
1. Tenant → Department → IdPs
2. Permissions
3. Roles → RoleGroup → RoleGroupRoles → RolePermissions
4. User → UserIdentity → UserRoles → UserRoleGroups → UserTenants → UserDepartments
5. PolicyDefinitions (base: user/read × 2)
6. PolicyDefinitions (ABAC platform defaults × 31 — from SeedAbacPolicies, IDs unchanged)
7. GlobalRoles (× 3)
8. PolicyDefinitions (PlatformSupport × 14 + PlatformAuditor × 7)
9. UserGlobalRoles (admin → PlatformAdmin)

**`Down()` order (reverse):**
- UserGlobalRoles → platform policies → GlobalRoles → ABAC policies → base policies → UserXxx associations → User + UserIdentity → RolePermissions → RoleGroupRoles → RoleGroup → Roles → Permissions → IdPs → Department → Tenant

### Step 6 — Update References to Old GUIDs

Anywhere the old GUIDs appear outside migrations (tests, constants files, appsettings), update to the new values identified in Step 2.

Common locations to check:
- `tests/` — integration test fixtures that hardcode seed IDs
- `appsettings*.json` — no seed IDs expected here, but verify

### Step 7 — Build and Test

```bash
cd D:/IFX
dotnet build IFX.sln
dotnet test IFX.sln
cd src/Frontend/IFX.FrontEnd
npm run test:run
```

All tests must pass.

### Step 8 — Handle Existing Databases

For any database that already has all 10 migrations applied, run this once to replace the 10 history rows with the 2 new ones:

```sql
-- Confirm all 10 exist first
SELECT MigrationId FROM auth.__EFMigrationsHistory ORDER BY MigrationId;

-- Replace history (adjust new MigrationIds to match generated timestamp prefix)
DELETE FROM [auth].[__EFMigrationsHistory];
INSERT INTO [auth].[__EFMigrationsHistory] ([MigrationId], [ProductVersion])
VALUES
    ('<timestamp>_InitialCreate', '8.0.x'),
    ('<timestamp>_InitialSeed',   '8.0.x');
```

> ⚠️ Do **NOT** run `dotnet ef database update` on an existing DB — it will try to recreate tables that exist.

### Step 9 — Update the Old Plan Document

Mark `/.claude/Plans/20260318-merge-ef-migrations.md` as superseded:

```markdown
**Status:** Superseded by `20260327-merge-ef-migrations-uuid-v7.md`
```

### Step 10 — Commit, Push, PR

```bash
git add -A
git commit -m "refactor: squash 10 EF migrations into InitialCreate + InitialSeed with UUID v7 seed IDs"
git push -u origin feature/merge-ef-migrations-v7
gh pr create --base main --title "refactor: squash EF migrations + UUID v7 seed IDs"
```

---

## File Change Summary

| Action | Files |
|--------|-------|
| **Delete** | 10 × `.cs` + 10 × `.Designer.cs` = 20 files |
| **Delete** | `IfxDbContextModelSnapshot.cs` (regenerated) |
| **Create** | `<ts>_InitialCreate.cs` + `.Designer.cs` |
| **Create** | `<ts>_InitialSeed.cs` + `.Designer.cs` |
| **Create** | `IfxDbContextModelSnapshot.cs` (regenerated) |
| **Update** | Any test/code files referencing old seed GUIDs |

Net: 21 files deleted → 5 files created + N test updates.

---

## Risks and Mitigations

| Risk | Mitigation |
|------|---|
| EF generates different column order or index names than expected | Compare generated Up() against old snapshot before proceeding |
| Old GUIDs referenced in integration tests | Step 2 grep finds all; update alongside migration changes |
| `FixPlatformPolicyUniqueIndex` index names never exist in fresh DB | Omit from merged InitialCreate — they're no-ops on a fresh install |
| Existing DB with partial migration set | Pre-condition check: all 10 must be applied before replacing history |
| `CreatedBy` backfill omitted from merged migration | Not needed — seed INSERTs set `CreatedBy` directly |
| `AdminUserId` referenced in `AddCreatedByToResources` backfill SQL | That migration is deleted; merged seed uses new AdminUserId in all INSERTs |
| PolicyDefinitions that used `NEWID()` now have fixed IDs | Fixed IDs are idempotent and testable — strictly better |

---

## Success Criteria

- [ ] 20 old migration files deleted
- [ ] 2 new migration files generated and manually completed
- [ ] All seed GUIDs are UUID v7 (version nibble = 7, variant = 8–B)
- [ ] `dotnet build IFX.sln` — 0 errors
- [ ] `dotnet test IFX.sln` — all tests pass
- [ ] `npm run test:run` — all frontend tests pass
- [ ] `docker-compose up -d` on a fresh environment creates all tables and seeds correctly
- [ ] `GET /health` returns Healthy
- [ ] Old plan `20260318-merge-ef-migrations.md` marked superseded
