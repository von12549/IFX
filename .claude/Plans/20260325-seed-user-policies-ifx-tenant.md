# Plan: Seed User ABAC Policies for IFX Tenant

**Date:** 2026-03-25
**Status:** To Do
**Tenant:** IFX
**Created/Updated by:** Xiaolong Feng

---

## Context

`UserPolicies.ReadOwnProfile` and `UserPolicies.ReadAnyProfile` are currently static
`AbacPolicy` objects defined in code (`UserPolicies.cs`). `ReadOwnProfile` is seeded into
`StaticAbacPolicyResolver` at DI startup and used directly by name in
`GetUserProfileQueryHandler`. The DB-backed policy resolver exists but the IFX tenant
has no `PolicyDefinition` rows — so every resolution falls through to the static fallback.

The goal is to promote these platform defaults into live DB rows for the IFX tenant,
and update the handler to resolve the policy dynamically so tenant admins can override it.

---

## Design Issue: Action Naming Conflict

`ReadOwnProfile` and `ReadAnyProfile` both target `resourceType = "user"`, `action = "read"`.
The DB unique constraint is `(TenantId, ResourceType, Action)` — only **one** row per tuple.

Resolution:

| Policy | Current action | Seeded as |
|--------|---------------|-----------|
| `ReadOwnProfile` | `read` | `user / read` — `[SameTenant, CreatedByMe]` |
| `ReadAnyProfile` | `read` (conflict) | **Not seeded.** Rename to `read_any` if a handler ever needs it, or delete the static constant. |

`ReadAnyProfile` is currently **unused** (defined but never referenced outside `UserPolicies.cs`).
It should be deleted as part of this task to avoid future confusion.

---

## Tasks

### 1. Delete `ReadAnyProfile` from `UserPolicies.cs`

`ReadAnyProfile` is unused and conflicts with the DB uniqueness model. Remove it.

File: `src/Modules/Auth/IFX.Modules.Auth.Application/Users/Authorization/UserPolicies.cs`

---

### 2. Seed the policy in an EF Core migration

Add a new migration `SeedIFXUserReadPolicy` that uses `migrationBuilder.Sql()` to insert
the row. The tenant ID and user ID are unknown at migration-write time, so the SQL must
resolve them via subqueries at migration-run time.

**`Up()`:**
```sql
DECLARE @TenantId  UNIQUEIDENTIFIER = (SELECT TOP 1 Id FROM auth.Tenants WHERE Name = 'IFX')
DECLARE @UserId    UNIQUEIDENTIFIER = (
    SELECT TOP 1 Id FROM auth.Users WHERE DisplayName = 'Xiaolong Feng')
DECLARE @PolicyId  UNIQUEIDENTIFIER = NEWID()
DECLARE @Now       DATETIME2        = GETUTCDATE()

IF @TenantId IS NOT NULL AND @UserId IS NOT NULL
   AND NOT EXISTS (
       SELECT 1 FROM auth.PolicyDefinitions
       WHERE TenantId = @TenantId AND ResourceType = 'user' AND Action = 'read')
BEGIN
    INSERT INTO auth.PolicyDefinitions
        (Id, TenantId, Name, Description, ResourceType, Action,
         ConditionsJson, IsActive, CreatedById, UpdatedById, CreatedAt, UpdatedAt)
    VALUES (
        @PolicyId, @TenantId,
        'Read Own Profile',
        'Allows a user to read their own profile within the same tenant.',
        'user', 'read',
        '[{"TemplateName":"SameTenant","Parameters":null},{"TemplateName":"CreatedByMe","Parameters":null}]',
        1, @UserId, @UserId, @Now, @Now)
END
```

**`Down()`:**
```sql
DELETE FROM auth.PolicyDefinitions
WHERE ResourceType = 'user' AND Action = 'read'
  AND TenantId = (SELECT TOP 1 Id FROM auth.Tenants WHERE Name = 'IFX')
```

> **Note:** If the IFX tenant or Xiaolong Feng's user row does not exist at migration
> time (e.g. a CI environment with an empty DB), the `IF` guard silently skips the
> insert. This is intentional — the static fallback in `StaticAbacPolicyResolver` keeps
> the system functional. Run the migration after seeding tenants and users.

---

### 3. Update `GetUserProfileQueryHandler` to use the resolver

Switch from the static policy reference to `AuthorizeWithResolvedPolicyAsync` so the
tenant's DB row (or static fallback) governs the check.

File: `src/Modules/Auth/IFX.Modules.Auth.Application/Users/Queries/GetUserProfile/GetUserProfileQueryHandler.cs`

Before:
```csharp
await _authorizationService.AuthorizeWithPolicyAsync(
    UserPolicies.ReadOwnProfile,
    resourceAttributes,
    ct: cancellationToken);
```

After:
```csharp
await _authorizationService.AuthorizeWithResolvedPolicyAsync(
    "user", "read",
    resourceAttributes,
    ct: cancellationToken);
```

The handler no longer needs to import `UserPolicies` — remove the using.

---

### 4. Keep `StaticAbacPolicyResolver` seeding as safety fallback

The `RegisterDefault("user", "read", UserPolicies.ReadOwnProfile)` in
`DependencyInjection.cs` should **remain** as a fallback. If the DB row is absent (fresh
dev environment, migration skipped due to missing tenant/user), policy resolution still
works instead of silently denying all requests.

---

### 5. Update tests

- `GetUserProfileQueryHandlerTests` — mock `IResourceAuthorizationService.AuthorizeWithResolvedPolicyAsync`
  instead of `AuthorizeWithPolicyAsync`.

---

### 6. Unused files audit (requires approval before deletion)

After all tasks above are complete, scan for files that have become unreferenced and
present them for approval before deleting. Expected candidates:

| File | Reason becomes unused |
|------|-----------------------|
| `UserPolicies.cs` | `ReadAnyProfile` removed; `ReadOwnProfile` only survives as the static fallback arg in `DependencyInjection.cs`. If the static fallback is also removed in a future cleanup, this file can be deleted entirely. **Do not delete until fallback is removed.** |
| `using IFX.Modules.Auth.Application.Users.Authorization` in `GetUserProfileQueryHandler.cs` | Removed in Task 3 — just a using, not a file. |

Steps:
1. Run a project-wide reference scan (`grep -r "UserPolicies"`) after completing Tasks 1–5.
2. List every file that has zero remaining references.
3. Present the list to the user for approval.
4. Delete only the approved files.

---

## Acceptance Criteria

- [ ] `ReadAnyProfile` removed from `UserPolicies.cs`
- [ ] Migration `SeedIFXUserReadPolicy` exists and inserts the `user/read` row for IFX tenant with `CreatedById` = Xiaolong Feng's user ID
- [ ] Migration is idempotent — running twice does not produce a duplicate row
- [ ] `GetUserProfileQueryHandler` calls `AuthorizeWithResolvedPolicyAsync("user", "read", ...)`
- [ ] Static fallback in `DependencyInjection.cs` retained for resilience
- [ ] All existing tests pass; `GetUserProfileQueryHandlerTests` updated
- [ ] Unused file audit completed and approved candidates removed
- [ ] The policy is visible in the Policy Management UI for the IFX tenant
