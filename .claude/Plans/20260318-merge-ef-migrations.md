# Plan: Merge EF Core Migrations into a Single Baseline

**Date:** 2026-03-18
**Branch:** `feature/merge-ef-migrations`
**Status:** Superseded by `20260327-merge-ef-migrations-uuid-v7.md`
**Base:** `main`
**Scope:** `IFX.Modules.Auth.Infrastructure` — `Persistence/Migrations/`
**Goal:** Squash all 14 incremental migrations into a single `InitialCreate` baseline migration that matches the current schema exactly, then update the model snapshot.

---

## Why Merge

14 migrations have accumulated across the development lifecycle. Merging them into a single baseline:
- Eliminates the overhead of running 14 migrations on a fresh database
- Removes historical Cognito-naming and schema-rename noise from the migration history
- Produces a clean, readable starting point for future migrations
- Reduces the risk of migration order bugs in CI/CD pipelines

---

## Pre-conditions (Must Be True Before Starting)

1. **No production databases exist yet** — or all existing databases have had all 14 migrations applied (i.e., `__EFMigrationsHistory` contains all 14 rows).
2. The solution builds with 0 errors (`dotnet build IFX.sln`).
3. All 269 tests pass (`dotnet test IFX.sln`).
4. On a clean feature branch: `feature/merge-ef-migrations`.

---

## Current State

### 14 Migrations to Replace

| # | File | What It Does |
|---|------|---|
| 1 | `20251222160950_InitialCreate` | Schema `cognito`, Users, LoginEvents, LogoutEvents, RegistrationFlowEvents, UserActivityLogs |
| 2 | `20251224110859_AddBirthDateToUsers` | Adds `BirthDate`, makes `PhoneNumber` NOT NULL |
| 3 | `20260106033815_AddUserRoles` | Creates `UserRoles` table, seeds Admin/User roles, adds `UserRoleId` FK to Users |
| 4 | `20260107055630_AddSsoUserRole` | Seeds `SsoUser` role |
| 5 | `20260110091959_AddIssuerToUsers` | Adds `Issuer` column to Users |
| 6 | `20260110095019_RenameColumn_CognitoUserId_To_Subject` | Renames `CognitoUserId` → `Subject` |
| 7 | `20260111031731_AddIdpTable` | Creates `Idps` table, seeds IFX Cognito and Test External Idp |
| 8 | `20260111120403_RenameSchemaFromCognitoToAuth` | Renames schema `cognito` → `auth` |
| 9 | `20260111122753_SplitUserTableIntoUserAndUserIdentity` | Splits Users into Users + UserIdentities, data migration |
| 10 | `20260111123319_DropUsersBackupTable` | Drops `UsersBackup` temp table |
| 11 | `20260114025631_AddIdpTypeColumn` | Adds `IdpType` to Idps |
| 12 | `20260114125506_AddIsPrimaryToIdp` | Adds `IsPrimary` to Idps with unique filtered index |
| 13 | `20260116100000_AddPendingRole` | Seeds `Pending` role |
| 14 | `20260123042554_AddEmailVerificationToken` | Creates `EmailVerificationTokens` table |

### Final Schema (to be expressed in one migration)

Schema: **`auth`**

Tables:
- `auth.Users` — Id, IsActive, UserRoleId (FK), DisplayName, CreatedAt, UpdatedAt
- `auth.UserIdentities` — Id, UserId (FK), IdpId (FK), Issuer, Subject, Email, FirstName, LastName, PhoneNumber, BirthDate, EmailVerified, PhoneNumberVerified, LastSyncedAt, CreatedAt, UpdatedAt
- `auth.UserRoles` — Id, RoleName (unique), Description, CreatedAt, UpdatedAt
- `auth.Idps` — Id, Name, Issuer (unique), IdpType, IsPrimary (unique filtered), Enabled, AutoProvisionEnabled, Authority, Description, LoginUrl, ExpectedAudiences, AllowedAlgs, RequiredScopes, ClaimMapping, ClockSkewSeconds, CreatedAt, UpdatedAt
- `auth.LoginEvents` — Id, UserId, LoginTimestamp, Success, FailureReason, IpAddress, UserAgent, CognitoSessionId, AccessToken, RefreshToken, TokenExpiresAt, DeviceInfo (owned)
- `auth.LogoutEvents` — Id, UserId, LogoutTimestamp, SessionDuration, IpAddress, Reason
- `auth.RegistrationFlowEvents` — Id, Email, Username, RegistrationInitiatedAt, RegistrationConfirmedAt, Status, ConfirmationCode, FailureReason, IpAddress, UserId
- `auth.UserActivityLogs` — Id, UserId, ActivityType, Description, Timestamp, IpAddress, Metadata
- `auth.EmailVerificationTokens` — Id, UserIdentityId (FK), Email, TokenHash (unique), Code, ExpiresAt, IsUsed, UsedAt, CreatedAt, UpdatedAt

Seed data to include in the merged migration:
- UserRoles: Admin, User, SsoUser, Pending
- Idps: "IFX Cognito" (Primary, Enabled), "Test External Idp" (not enabled)

---

## Implementation Steps

### Step 1 — Create Feature Branch

```bash
git checkout main
git pull
git checkout -b feature/merge-ef-migrations
```

### Step 2 — Delete All Existing Migration Files

Delete all 14 migration `.cs` files and their `Designer.cs` counterparts (28 files total):

```
Persistence/Migrations/20251222160950_InitialCreate.cs
Persistence/Migrations/20251222160950_InitialCreate.Designer.cs
Persistence/Migrations/20251224110859_AddBirthDateToUsers.cs
Persistence/Migrations/20251224110859_AddBirthDateToUsers.Designer.cs
Persistence/Migrations/20260106033815_AddUserRoles.cs
Persistence/Migrations/20260106033815_AddUserRoles.Designer.cs
Persistence/Migrations/20260107055630_AddSsoUserRole.cs
Persistence/Migrations/20260107055630_AddSsoUserRole.Designer.cs
Persistence/Migrations/20260110091959_AddIssuerToUsers.cs
Persistence/Migrations/20260110091959_AddIssuerToUsers.Designer.cs
Persistence/Migrations/20260110095019_RenameColumn_CognitoUserId_To_Subject.cs
Persistence/Migrations/20260110095019_RenameColumn_CognitoUserId_To_Subject.Designer.cs
Persistence/Migrations/20260111031731_AddIdpTable.cs
Persistence/Migrations/20260111031731_AddIdpTable.Designer.cs
Persistence/Migrations/20260111120403_RenameSchemaFromCognitoToAuth.cs
Persistence/Migrations/20260111120403_RenameSchemaFromCognitoToAuth.Designer.cs
Persistence/Migrations/20260111122753_SplitUserTableIntoUserAndUserIdentity.cs
Persistence/Migrations/20260111122753_SplitUserTableIntoUserAndUserIdentity.Designer.cs
Persistence/Migrations/20260111123319_DropUsersBackupTable.cs
Persistence/Migrations/20260111123319_DropUsersBackupTable.Designer.cs
Persistence/Migrations/20260114025631_AddIdpTypeColumn.cs
Persistence/Migrations/20260114025631_AddIdpTypeColumn.Designer.cs
Persistence/Migrations/20260114125506_AddIsPrimaryToIdp.cs
Persistence/Migrations/20260114125506_AddIsPrimaryToIdp.Designer.cs
Persistence/Migrations/20260116100000_AddPendingRole.cs
Persistence/Migrations/20260116100000_AddPendingRole.Designer.cs
Persistence/Migrations/20260123042554_AddEmailVerificationToken.cs
Persistence/Migrations/20260123042554_AddEmailVerificationToken.Designer.cs
Persistence/Migrations/IfxDbContextModelSnapshot.cs   ← regenerated in Step 4
```

### Step 3 — Generate the New Baseline Migration

From the solution root:

```bash
cd src/Modules/Auth/IFX.Modules.Auth.Infrastructure
dotnet ef migrations add InitialCreate \
  --startup-project ../../../ApiHost/IFX.ApiHost \
  --context IfxDbContext
```

This generates:
- `Persistence/Migrations/<timestamp>_InitialCreate.cs` — `Up()` creates all tables directly in `auth` schema
- `Persistence/Migrations/<timestamp>_InitialCreate.Designer.cs`
- `Persistence/Migrations/IfxDbContextModelSnapshot.cs` (regenerated)

### Step 4 — Add Seed Data to the New Migration

The auto-generated migration only creates schema. Edit the new `InitialCreate.cs` to add seed data at the end of `Up()`:

```csharp
// Seed UserRoles
migrationBuilder.InsertData(
    schema: "auth", table: "UserRoles",
    columns: new[] { "Id", "RoleName", "Description", "CreatedAt", "UpdatedAt" },
    values: new object[,]
    {
        { new Guid("..."), "Admin",   "Administrator role",                                         now, now },
        { new Guid("..."), "User",    "Standard user role",                                         now, now },
        { new Guid("..."), "SsoUser", "User authenticated via SSO provider",                        now, now },
        { new Guid("..."), "Pending", "User with incomplete registration, requires profile completion", now, now },
    });

// Seed Idps
migrationBuilder.InsertData(
    schema: "auth", table: "Idps",
    columns: new[] { "Id", "Name", "Issuer", "Authority", "Description", "LoginUrl",
                     "IdpType", "IsPrimary", "Enabled", "AutoProvisionEnabled",
                     "ExpectedAudiences", "AllowedAlgs", "RequiredScopes",
                     "ClaimMapping", "ClockSkewSeconds", "CreatedAt", "UpdatedAt" },
    values: new object[,]
    {
        { new Guid("..."), "IFX Cognito", "https://cognito-idp.ap-southeast-2.amazonaws.com/...",
          "https://cognito-idp.ap-southeast-2.amazonaws.com/...", "IFX AWS Cognito Identity Provider",
          "", "Internal", true, true, true, "[]", "[]", "[]", "{}", 300, now, now },
        { new Guid("..."), "Test External Idp", "https://test-external-idp.example.com",
          "https://test-external-idp.example.com", "Test External Identity Provider",
          "https://test-external-idp.example.com/login", "External", false, false, false,
          "[]", "[]", "[]", "{}", 300, now, now },
    });
```

Use **fixed GUIDs** (not `Guid.NewGuid()`) so the seed is idempotent and the snapshot is stable.

Also add the corresponding `Down()` delete statements:
```csharp
migrationBuilder.DeleteData(schema: "auth", table: "Idps", keyColumn: "Id", keyValue: ...);
migrationBuilder.DeleteData(schema: "auth", table: "UserRoles", keyColumn: "Id", keyValue: ...);
```

### Step 5 — Verify Migration is Correct

Build to confirm no errors:
```bash
dotnet build IFX.sln
```

Inspect the generated `Up()` to confirm it:
- Creates `auth` schema first
- Creates all 9 tables in the correct FK dependency order (UserRoles → Users; Idps → UserIdentities)
- Includes all unique/filtered indexes
- Includes all seed data

### Step 6 — Handle Existing Databases (if any)

**Fresh database:** The new migration runs cleanly — done.

**Existing database (already at migration #14):**
```sql
-- Run once on each existing database to replace the 14 history rows with 1
DELETE FROM [auth].[__EFMigrationsHistory];
INSERT INTO [auth].[__EFMigrationsHistory] ([MigrationId], [ProductVersion])
VALUES ('<new-timestamp>_InitialCreate', '8.0.x');
```

> ⚠️ **IMPORTANT:** Do NOT run `dotnet ef database update` on an existing database — it will try to create tables that already exist. Only update `__EFMigrationsHistory`.

### Step 7 — Run Tests

```bash
dotnet test IFX.sln
```

All 269 tests must pass. Integration tests exercise `IfxDbContext` via in-memory DB and will validate the schema is correct.

### Step 8 — Commit, Push, PR

```bash
git add -A
git commit -m "refactor: squash 14 EF migrations into single InitialCreate baseline"
git push -u origin feature/merge-ef-migrations
gh pr create --base main --title "refactor: squash EF migrations into baseline"
```

---

## File Change Summary

| Action | Files |
|--------|-------|
| **Delete** | 14 × `.cs` + 14 × `.Designer.cs` = 28 files |
| **Delete** | `IfxDbContextModelSnapshot.cs` (regenerated) |
| **Create** | `<timestamp>_InitialCreate.cs` |
| **Create** | `<timestamp>_InitialCreate.Designer.cs` |
| **Create** | `IfxDbContextModelSnapshot.cs` (regenerated) |

Net result: 28 files deleted → 3 files created.

---

## Risks and Mitigations

| Risk | Mitigation |
|------|---|
| Existing DB out of sync | Update `__EFMigrationsHistory` manually (Step 6) |
| Seed data GUIDs differ between environments | Use hardcoded fixed GUIDs in `InsertData` calls |
| Entity configs generate different schema than expected | Validate by diffing old snapshot with new one before deleting old files |
| `Down()` migration incorrect | Rarely used in production; unit-test by running `Down()` against in-memory DB |
| Missing indexes in generated migration | Compare generated file against current snapshot indexes before committing |

---

## Success Criteria

- [ ] All 28 old migration files deleted
- [ ] Single `InitialCreate` migration generated that creates the full schema in one pass
- [ ] Seed data (4 roles, 2 IdPs) present in the migration
- [ ] `dotnet build IFX.sln` — 0 errors
- [ ] `dotnet test IFX.sln` — all 269 tests pass
- [ ] Fresh `docker-compose up -d` creates all tables correctly
- [ ] `GET /health` returns Healthy
