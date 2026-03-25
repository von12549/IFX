# Plan: Permission Action Expansion — `<resource>:<action>` Format

**Date:** 2026-03-25
**Branch:** `feature/permission-action-expansion`
**Status:** Planned

---

## Goal

Replace the coarse `<resource>.<action>` permission format (with only `Read`/`Write` actions) with a
fine-grained `<resource>:<action>` format (colon separator, expanded action vocabulary). Update all
seeded data, endpoint guards, and role-permission assignments.

---

## Analysis

### Current state — 18 permissions

| Permission | Used by | Assigned to roles |
|---|---|---|
| `User.Read` | GET /usermanagement/users, GET /users/{id} | Admin, User, SsoUser, PendingUser |
| `User.Write` | PUT/POST/DELETE /usermanagement/users/... | Admin, User |
| `Role.Read` | GET /role, GET /role/{id} | Admin |
| `Role.Write` | POST/PUT/DELETE /role/... | Admin |
| `RoleGroup.Read` | GET /rolegroup | Admin |
| `RoleGroup.Write` | POST/PUT/DELETE /rolegroup/... | Admin |
| `Permission.Read` | GET /permission | Admin |
| `Permission.Write` | POST/PUT/DELETE /permission/... | Admin |
| `Idp.Read` | GET /idp, GET /idp/{id} | Admin |
| `Idp.Write` | POST/PUT/DELETE /idp/... | Admin |
| `Tenant.Read` | GET /tenant, GET /tenant/{id} | Admin |
| `Tenant.Write` | POST/PUT/DELETE /tenant/... | Admin |
| `Department.Read` | GET /department, GET /department/{id} | Admin |
| `Department.Write` | POST/PUT/DELETE /department/... | Admin |
| `Policy.Read` | GET /policy, GET /policy/templates | Admin |
| `Policy.Write` | POST/PUT/DELETE /policy/... | Admin |
| `Platform.Policy.Read` | GET /platform/policy | Admin |
| `Platform.Policy.Write` | POST/PUT/DELETE /platform/policy/... | Admin |

### Problems with the current design

1. **`Read` conflates two different operations** — listing a collection (`GET /users`) and fetching a
   single record (`GET /users/{id}`) require the same permission. Fine-grained control is impossible.

2. **`Write` is too broad** — create, update, and delete are bundled. You cannot grant "create only"
   or "delete only" access.

3. **No workflow actions** — `approve`, `reject`, `submit` cannot be expressed as RBAC permissions.
   These will be needed when business modules (e.g. documents, leave requests) are added.

4. **No data transfer actions** — `export` and `import` are distinct security concerns
   (bulk data access vs bulk data ingestion) that cannot be expressed today.

5. **Dot separator is ambiguous** — `Platform.Policy.Read` reads as a three-part name where the
   boundary between resource and action is unclear.

6. **`User.Write` is over-assigned** — the `User` role received `User.Write` historically to allow
   profile self-service. With ABAC now protecting `PUT /user/profile` (via `CreatedByMe` condition),
   a `User.Write` permission is no longer needed for self-service users. This should be corrected.

### Design question: Platform / System Admin role

**Current problem:** Permissions are stored globally in `auth.Permissions`, but they are assigned
to tenant-scoped `Roles` (each `Role` has a required `TenantId`). This creates an architectural
inconsistency:

- `Tenant:create`/`Tenant:delete` — these are **platform operations** that no tenant's Admin
  should perform. Creating a tenant from within a tenant context is conceptually wrong.
- `Platform.Policy:*` — global default policies should only be managed by platform admins, not
  by a tenant's own Admin.

**Recommendation: Yes — introduce platform-level roles (Phase 2 of this plan).**

The cleanest solution follows the same pattern used for `PolicyDefinition.TenantId`:
make `Role.TenantId` **nullable**. `TenantId = NULL` → platform role, applies globally.

| Scope | TenantId | Applies to |
|---|---|---|
| Tenant role | `<guid>` | Users within that specific tenant |
| Platform role | `NULL` | Platform admins, regardless of active tenant |

`ICurrentUser.Permissions` would include platform role permissions alongside tenant role permissions.
Permissions like `Tenant:create`, `Tenant:delete`, `Platform.Policy:*` would be assigned **only** to
platform roles, never to tenant roles.

This is a meaningful structural change to the user identity model and is scoped as **Phase 2** below.

---

## New Permission Format

**Separator:** `:` (colon) — clearly distinguishes resource from action; avoids ambiguity with
the `.` used in resource namespacing (e.g. `Platform.Policy` is one resource, `create` is the action).

**Action vocabulary:**

| Action | Meaning | HTTP analogue |
|---|---|---|
| `list` | Fetch a paginated/filtered collection | GET / |
| `read` | Fetch a single record by ID | GET /{id} |
| `create` | Create a new record | POST / |
| `update` | Modify an existing record | PUT /{id} |
| `delete` | Remove a record | DELETE /{id} |
| `approve` | Approve a pending workflow item | POST /{id}/approve |
| `reject` | Reject a pending workflow item | POST /{id}/reject |
| `submit` | Submit an item for review | POST /{id}/submit |
| `export` | Export data in bulk | GET /export |
| `import` | Import data in bulk | POST /import |

---

## New Permission Table — 45 permissions

### Auth module (tenant-scoped)

| New Permission | Replaces | Description |
|---|---|---|
| `User:list` | `User.Read` (list) | List users within tenant |
| `User:read` | `User.Read` (single) | View a specific user |
| `User:create` | `User.Write` | Create a user |
| `User:update` | `User.Write` | Update user / assign roles, depts, tenants |
| `User:delete` | `User.Write` | Deactivate/delete a user |
| `Role:list` | `Role.Read` | List roles |
| `Role:read` | `Role.Read` | View a specific role |
| `Role:create` | `Role.Write` | Create a role |
| `Role:update` | `Role.Write` | Update a role / assign permissions |
| `Role:delete` | `Role.Write` | Delete a role |
| `RoleGroup:list` | `RoleGroup.Read` | List role groups |
| `RoleGroup:read` | `RoleGroup.Read` | View a specific role group |
| `RoleGroup:create` | `RoleGroup.Write` | Create a role group |
| `RoleGroup:update` | `RoleGroup.Write` | Update a role group / assign roles |
| `RoleGroup:delete` | `RoleGroup.Write` | Delete a role group |
| `Permission:list` | `Permission.Read` | List permissions |
| `Permission:read` | `Permission.Read` | View a specific permission |
| `Permission:create` | `Permission.Write` | Create a permission |
| `Permission:update` | `Permission.Write` | Update a permission |
| `Permission:delete` | `Permission.Write` | Delete a permission |
| `Idp:list` | `Idp.Read` | List identity providers |
| `Idp:read` | `Idp.Read` | View a specific IdP |
| `Idp:create` | `Idp.Write` | Create an IdP |
| `Idp:update` | `Idp.Write` | Update an IdP |
| `Idp:delete` | `Idp.Write` | Delete an IdP |
| `Department:list` | `Department.Read` | List departments |
| `Department:read` | `Department.Read` | View a specific department |
| `Department:create` | `Department.Write` | Create a department |
| `Department:update` | `Department.Write` | Update a department |
| `Department:delete` | `Department.Write` | Delete a department |
| `Policy:list` | `Policy.Read` | List tenant policies + available templates |
| `Policy:read` | `Policy.Read` | View a specific tenant policy |
| `Policy:create` | `Policy.Write` | Create a tenant policy |
| `Policy:update` | `Policy.Write` | Update a tenant policy |
| `Policy:delete` | `Policy.Write` | Delete a tenant policy |

### Platform-scoped (Phase 2: assigned to platform role only)

| New Permission | Replaces | Description |
|---|---|---|
| `Tenant:list` | `Tenant.Read` | List all tenants |
| `Tenant:read` | `Tenant.Read` | View a specific tenant |
| `Tenant:create` | `Tenant.Write` | Create a tenant |
| `Tenant:update` | `Tenant.Write` | Update a tenant |
| `Tenant:delete` | `Tenant.Write` | Delete a tenant |
| `Platform.Policy:list` | `Platform.Policy.Read` | List platform policies |
| `Platform.Policy:read` | `Platform.Policy.Read` | View a specific platform policy |
| `Platform.Policy:create` | `Platform.Policy.Write` | Create a platform policy |
| `Platform.Policy:update` | `Platform.Policy.Write` | Update a platform policy |
| `Platform.Policy:delete` | `Platform.Policy.Write` | Delete a platform policy |

### Seeded but unassigned (available for future business modules)

| Action | Purpose |
|---|---|
| `approve`, `reject`, `submit` | Workflow state transitions |
| `export`, `import` | Bulk data operations |

These are seeded in the `Permissions` table as generic documentation (e.g. `User:export`,
`User:import`) when the resource warrants them, but not yet assigned to any role.

---

## Endpoint → New Permission Mapping

### User Management (`/api/v1/usermanagement`)

| Endpoint | Method | Old | New |
|---|---|---|---|
| `/users` | GET | `User.Read` | `User:list` |
| `/users/{id}` | GET | `User.Read` | `User:read` |
| `/users/{id}` | PUT | `User.Write` | `User:update` |
| `/users/{id}/roles` | POST | `User.Write` | `User:update` |
| `/users/{id}/roles/{roleId}` | DELETE | `User.Write` | `User:update` |
| `/users/{id}/rolegroups` | POST | `User.Write` | `User:update` |
| `/users/{id}/rolegroups/{id}` | DELETE | `User.Write` | `User:update` |
| `/users/{id}/tenants` | POST | `User.Write` | `User:update` |
| `/users/{id}/tenants/{id}` | DELETE | `User.Write` | `User:update` |
| `/users/{id}/departments` | POST | `User.Write` | `User:update` |
| `/users/{id}/departments/{id}` | DELETE | `User.Write` | `User:update` |
| `/users/{id}/send-test-email` | POST | `User.Write` | `User:update` |

### Role (`/api/v1/role`)

| Endpoint | Method | Old | New |
|---|---|---|---|
| `/role` | GET | `Role.Read` | `Role:list` |
| `/role/{id}` | GET | `Role.Read` | `Role:read` |
| `/role` | POST | `Role.Write` | `Role:create` |
| `/role/{id}` | PUT | `Role.Write` | `Role:update` |
| `/role/{id}` | DELETE | `Role.Write` | `Role:delete` |
| `/role/{id}/permissions` | POST | `Role.Write` | `Role:update` |
| `/role/{id}/permissions/{id}` | DELETE | `Role.Write` | `Role:update` |

### RoleGroup (`/api/v1/rolegroup`)

| Endpoint | Method | Old | New |
|---|---|---|---|
| `/rolegroup` | GET | `RoleGroup.Read` | `RoleGroup:list` |
| `/rolegroup` | POST | `RoleGroup.Write` | `RoleGroup:create` |
| `/rolegroup/{id}` | PUT | `RoleGroup.Write` | `RoleGroup:update` |
| `/rolegroup/{id}` | DELETE | `RoleGroup.Write` | `RoleGroup:delete` |
| `/rolegroup/{id}/roles` | POST | `RoleGroup.Write` | `RoleGroup:update` |
| `/rolegroup/{id}/roles/{id}` | DELETE | `RoleGroup.Write` | `RoleGroup:update` |

### Permission (`/api/v1/permission`)

| Endpoint | Method | Old | New |
|---|---|---|---|
| `/permission` | GET | `Permission.Read` | `Permission:list` |
| `/permission` | POST | `Permission.Write` | `Permission:create` |
| `/permission/{id}` | PUT | `Permission.Write` | `Permission:update` |
| `/permission/{id}` | DELETE | `Permission.Write` | `Permission:delete` |

### IdP (`/api/v1/idp`)

| Endpoint | Method | Old | New |
|---|---|---|---|
| `/idp` | GET | `Idp.Read` | `Idp:list` |
| `/idp/{id}` | GET | `Idp.Read` | `Idp:read` |
| `/idp` | POST | `Idp.Write` | `Idp:create` |
| `/idp/{id}` | PUT | `Idp.Write` | `Idp:update` |

### Tenant (`/api/v1/tenant`)

| Endpoint | Method | Old | New |
|---|---|---|---|
| `/tenant` | GET | `Tenant.Read` | `Tenant:list` |
| `/tenant/{id}` | GET | `Tenant.Read` | `Tenant:read` |
| `/tenant` | POST | `Tenant.Write` | `Tenant:create` |
| `/tenant/{id}` | PUT | `Tenant.Write` | `Tenant:update` |
| `/tenant/{id}` | DELETE | `Tenant.Write` | `Tenant:delete` |

### Department (`/api/v1/department`)

| Endpoint | Method | Old | New |
|---|---|---|---|
| `/department` | GET | `Department.Read` | `Department:list` |
| `/department/{id}` | GET | `Department.Read` | `Department:read` |
| `/department` | POST | `Department.Write` | `Department:create` |
| `/department/{id}` | PUT | `Department.Write` | `Department:update` |
| `/department/{id}` | DELETE | `Department.Write` | `Department:delete` |

### Tenant Policy (`/api/v1/policy`)

| Endpoint | Method | Old | New |
|---|---|---|---|
| `/policy` | GET | `Policy.Read` | `Policy:list` |
| `/policy/templates` | GET | `Policy.Read` | `Policy:list` |
| `/policy` | POST | `Policy.Write` | `Policy:create` |
| `/policy/{id}` | PUT | `Policy.Write` | `Policy:update` |
| `/policy/{id}` | DELETE | `Policy.Write` | `Policy:delete` |

### Platform Policy (`/api/v1/platform/policy`)

| Endpoint | Method | Old | New |
|---|---|---|---|
| `/platform/policy` | GET | `Platform.Policy.Read` | `Platform.Policy:list` |
| `/platform/policy` | POST | `Platform.Policy.Write` | `Platform.Policy:create` |
| `/platform/policy/{id}` | PUT | `Platform.Policy.Write` | `Platform.Policy:update` |
| `/platform/policy/{id}` | DELETE | `Platform.Policy.Write` | `Platform.Policy:delete` |

---

## New Role-Permission Assignments

### Admin (tenant-scoped — Phase 1)

All 45 permissions. In Phase 2, `Tenant:*` and `Platform.Policy:*` will be removed from this
tenant-scoped Admin role and reassigned exclusively to the platform Admin role.

### User

`User:read` only.

> **Rationale:** Previously `User.Write` was assigned to allow profile self-service. This was
> incorrect — `PUT /user/profile` is an authenticated self-service endpoint protected by ABAC
> (`CreatedByMe` condition), not by an RBAC permission. Admin-level user management
> (`PUT /usermanagement/users/{id}`) correctly requires `User:update`, which the `User` role
> should NOT have.

### SsoUser

`User:read` only. (unchanged intent)

### PendingUser

`User:read` only. (unchanged intent)

---

## Implementation Tasks

### Phase 1 — Permission format change (this branch)

- [ ] **Task 1** — EF migration: `ReplacePermissionsWithExpandedActions`
  - Insert 45 new permissions (idempotent)
  - Re-seed `RolePermissions` using new permission names
  - Delete old 18 permissions (cascade deletes old `RolePermissions` rows)
  - All in one migration, wrapped in SQL transaction

- [ ] **Task 2** — Update all `RequirePermission()` calls in Presentation layer (10 endpoint files)
  - Map old string → new string per the endpoint table above

- [ ] **Task 3** — Update `PermissionAuthorizationPolicyProvider` comment/docs (code is dynamic, no logic change)

- [ ] **Task 4** — Update CLAUDE.md and `docs/abac.md` permission table

- [ ] **Task 5** — Run all tests; fix any that assert old permission strings

- [ ] **Task 6** — Update frontend `api.ts` / MSW handlers if any permission strings are hardcoded

### Phase 2 — Platform Admin role (follow-up branch: `feature/platform-admin-role`)

- [ ] **Task A** — Make `Role.TenantId` nullable (EF migration)
  - Same pattern as `PolicyDefinition.TenantId = NULL` for platform rows
  - Add filtered unique index: `UX_Roles_Platform_Name WHERE TenantId IS NULL`

- [ ] **Task B** — Seed platform `Admin` role (`TenantId = NULL`)

- [ ] **Task C** — Update `ICurrentUser` / `CurrentUser` to include platform role permissions
  regardless of active `X-Tenant-Id`

- [ ] **Task D** — Move `Tenant:*` and `Platform.Policy:*` from tenant Admin to platform Admin

- [ ] **Task E** — Update `ICurrentUser.TenantId` claim validation to allow platform roles
  to operate without a tenant header

---

## Migration Strategy

Single migration `ReplacePermissionsWithExpandedActions`:

```sql
-- Step 1: Insert 45 new permissions (idempotent)
INSERT INTO [auth].[Permissions] ([Id], [Name], [Description], ...)
SELECT v.[Id], v.[Name], v.[Description], ...
FROM (VALUES
    (NEWID(), 'User:list',   'List users within tenant'),
    (NEWID(), 'User:read',   'View a specific user'),
    ...
) AS v([Id], [Name], [Description])
WHERE NOT EXISTS (SELECT 1 FROM [auth].[Permissions] p WHERE p.[Name] = v.[Name])

-- Step 2: Re-seed RolePermissions (map old → new, idempotent)
-- Admin gets all 45
-- User gets User:read only
-- SsoUser gets User:read only
-- PendingUser gets User:read only

-- Step 3: Delete old permissions (cascades RolePermissions via FK)
DELETE FROM [auth].[RolePermissions]
WHERE [PermissionsId] IN (SELECT [Id] FROM [auth].[Permissions]
    WHERE [Name] IN ('User.Read', 'User.Write', ... 18 old names ...))
DELETE FROM [auth].[Permissions]
WHERE [Name] IN ('User.Read', 'User.Write', ... 18 old names ...)
```

---

## Notes and Advice

1. **The colon separator is the right call.** Using `.` was ambiguous — `Platform.Policy.Read`
   looks like a three-segment dotted path. `Platform.Policy:read` clearly reads as resource =
   `Platform.Policy`, action = `read`.

2. **`list` vs `read` is a meaningful distinction.** A reporting role might need `list` without
   `read` (see summary counts but not individual records). A service account might need `read`
   without `list`. Don't merge them back.

3. **`approve`/`reject`/`submit` are workflow actions, not CRUD.** They should be added per
   resource only when that resource has a workflow. Don't pre-seed them on all resources — add
   them in the migration that introduces the workflow feature (e.g. `Document:approve`).

4. **`export`/`import` are high-value security controls.** Bulk data access/ingestion deserves
   explicit permission gating. Add them when a resource grows an import/export feature.

5. **Don't conflate `User:update` with role/dept assignment.** Today `POST /users/{id}/roles`
   uses `User:update` because it modifies user state. If finer control is ever needed, these
   could become `User:assign-role` etc. For now `User:update` is correct.

6. **Phase 2 is important to do soon.** As long as `Tenant:create` is assigned to a
   tenant-scoped Admin role, any tenant Admin can theoretically hit the tenant creation endpoint
   if they know its path. The permission gate works, but the conceptual model is wrong.
   Phase 2 fixes this properly.
