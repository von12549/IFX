# Plan: Multi-Tenant Support

**Branch:** `feature/multi-tenant`
**Date:** 2026-03-22
**Status:** Complete — PR #10 open

---

## Goal

Add multi-tenant support to IFX. Phase 1 introduces the `Tenant` and `Department` entities, scopes `Role`, `RoleGroup`, and `Idp` to tenants, adds CRUD endpoints for both new entities, seeds initial data, and reflects all changes in the React frontend.

---

## Design Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Primary Tenant storage | `PrimaryTenantId` FK on `Users` | Simpler than `IsPrimary` flag on join table; enforced at application layer |
| Permission naming | `Tenant.Read`, `Tenant.Write`, `Department.Read`, `Department.Write` | Consistent with existing `User.Read`, `Role.Read` convention |
| Role/RoleGroup name uniqueness | `UNIQUE (TenantId, Name)` | Same name allowed in different tenants |
| `NameExistsAsync` signature | Add `tenantId` parameter | Required after uniqueness scope change |
| Permission resolution | Merge all tenant roles (no per-tenant filter) | Non-breaking for existing claims transformation; per-tenant filtering is Phase 2 |
| User-Department tenant integrity | Application-layer enforcement | Consistent with how authorization rules are handled elsewhere |
| Migration approach for NOT NULL TenantId | Add nullable → backfill → make NOT NULL | Required to avoid migration failure on non-empty database |

---

## Affected Entities / Tables

### New Tables
| Table | Columns |
|-------|---------|
| `auth.Tenants` | `Id`, `Name`, `Description`, `CreatedAt`, `UpdatedAt` |
| `auth.Departments` | `Id`, `Name`, `Description`, `TenantId` (FK → Tenants), `CreatedAt`, `UpdatedAt` |
| `auth.UserTenants` | `UsersId` (FK → Users), `TenantsId` (FK → Tenants) — join table |
| `auth.UserDepartments` | `UsersId` (FK → Users), `DepartmentsId` (FK → Departments) — join table |

### Modified Tables
| Table | Change |
|-------|--------|
| `auth.Users` | Add `PrimaryTenantId` (nullable FK → Tenants) |
| `auth.Roles` | Add `TenantId` (FK → Tenants, NOT NULL after backfill); change unique index from `(Name)` to `(TenantId, Name)` |
| `auth.RoleGroups` | Add `TenantId` (FK → Tenants, NOT NULL after backfill); change unique index from `(Name)` to `(TenantId, Name)` |
| `auth.Idps` | Add `TenantId` (FK → Tenants, NOT NULL after backfill) |

---

## Seed Data

### Permissions (seeded in migration)
- `Tenant.Read`
- `Tenant.Write`
- `Department.Read`
- `Department.Write`

### Roles
- `Admin` role gets all 4 new permissions added

### Tenant
- Name: `IFX`, Description: `Default tenant`

### Department
- Name: `Test`, Description: `Test department`, TenantId: IFX tenant

### Backfill
- All existing `Roles`, `RoleGroups`, `Idps` rows → assign IFX `TenantId`

### User Link
- User `8314F7DA-2F5D-4128-A705-957CE0C3972E` → linked to Tenant IFX (via `UserTenants` join table) and Department Test (via `UserDepartments` join table)
- Set `PrimaryTenantId` = IFX for that user

---

## Implementation Order

### Group 1 — Domain Layer

1. **`Tenant` entity** (`Domain/Authorization/Tenant.cs`)
   - Properties: `Name`, `Description`, `CreatedAt`, `UpdatedAt`
   - Factory: `Tenant.Create(name, description)`
   - Methods: `Update(name, description)`

2. **`Department` entity** (`Domain/Authorization/Department.cs`)
   - Properties: `Name`, `Description`, `TenantId`, `Tenant` nav
   - Factory: `Department.Create(name, description, tenantId)`
   - Methods: `Update(name, description)`

3. **Repository interfaces** (`Domain/Authorization/`)
   - `ITenantRepository`: `GetByIdAsync`, `GetAllAsync`, `NameExistsAsync`, `AddAsync`, `UpdateAsync`, `DeleteAsync`
   - `IDepartmentRepository`: `GetByIdAsync`, `GetAllAsync`, `GetByTenantIdAsync`, `NameExistsAsync(name, tenantId)`, `AddAsync`, `UpdateAsync`, `DeleteAsync`

4. **Update `User` entity** (`Domain/Users/User.cs`)
   - Add `PrimaryTenantId` (nullable `Guid?`)
   - Add `_tenants` / `Tenants` collection (M2M)
   - Add `_departments` / `Departments` collection (M2M)
   - Methods: `SetPrimaryTenant(Guid tenantId)`, `AddTenant(Tenant)`, `RemoveTenant(Guid)`, `AddDepartment(Department)`, `RemoveDepartment(Guid)`

5. **Update `Role` entity** (`Domain/Authorization/Role.cs`)
   - Add `TenantId` property

6. **Update `RoleGroup` entity** (`Domain/Authorization/RoleGroup.cs`)
   - Add `TenantId` property

7. **Update `Idp` entity** (`Domain/Identity/Idp.cs`)
   - Add `TenantId` property

8. **Update `IUnitOfWork`** (`Domain/`)
   - Add `ITenantRepository Tenants { get; }`
   - Add `IDepartmentRepository Departments { get; }`

9. **Update `IRoleRepository`**
   - Change `NameExistsAsync(string name, ...)` → `NameExistsAsync(string name, Guid tenantId, ...)`
   - Add `NameExistsAsync(string name, Guid tenantId, Guid excludeId, ...)` overload

10. **Update `IRoleGroupRepository`** — same `NameExistsAsync` signature change

---

### Group 2 — Infrastructure Layer

11. **`TenantConfiguration`** (`Infrastructure/Authorization/Configurations/TenantConfiguration.cs`)
    - Table: `auth.Tenants`; unique index on `Name`

12. **`DepartmentConfiguration`** (`Infrastructure/Authorization/Configurations/DepartmentConfiguration.cs`)
    - Table: `auth.Departments`; FK to Tenants; unique index on `(TenantId, Name)`

13. **Update `UserConfiguration`**
    - Add M2M `Users ↔ Tenants` → join table `auth.UserTenants`
    - Add M2M `Users ↔ Departments` → join table `auth.UserDepartments`
    - Add `PrimaryTenantId` FK → `auth.Tenants`

14. **Update `RoleConfiguration`**
    - Add `TenantId` FK → `auth.Tenants`
    - Change unique index from `(Name)` to `(TenantId, Name)`

15. **Update `RoleGroupConfiguration`**
    - Add `TenantId` FK → `auth.Tenants`
    - Change unique index from `(Name)` to `(TenantId, Name)`

16. **Update `IdpConfiguration`**
    - Add `TenantId` FK → `auth.Tenants`

17. **Repository implementations**
    - `TenantRepository`: `ITenantRepository` implementation
    - `DepartmentRepository`: `IDepartmentRepository` implementation

18. **Update `UnitOfWork`** — add `Tenants` and `Departments` properties

19. **Update existing repositories** (`RoleRepository`, `RoleGroupRepository`) — update `NameExistsAsync` to filter by `TenantId`

20. **Add migration** `AddMultiTenantSupport`
    - Add `Tenants` table
    - Add `Departments` table
    - Add `UserTenants` join table
    - Add `UserDepartments` join table
    - Add `PrimaryTenantId` to `Users` (nullable)
    - Add `TenantId` to `Roles` as **nullable**
    - Add `TenantId` to `RoleGroups` as **nullable**
    - Add `TenantId` to `Idps` as **nullable**
    - Drop old unique indexes on `Roles.Name` and `RoleGroups.Name`
    - Insert seed `Tenant` ("IFX"), `Department` ("Test")
    - Insert seed permissions: `Tenant.Read`, `Tenant.Write`, `Department.Read`, `Department.Write`
    - Assign new permissions to `Admin` role
    - `UPDATE Roles SET TenantId = <ifxId>` (backfill)
    - `UPDATE RoleGroups SET TenantId = <ifxId>` (backfill)
    - `UPDATE Idps SET TenantId = <ifxId>` (backfill)
    - Alter `Roles.TenantId`, `RoleGroups.TenantId`, `Idps.TenantId` to **NOT NULL**
    - Add new unique indexes: `(TenantId, Name)` on `Roles` and `RoleGroups`
    - Link User `8314F7DA-2F5D-4128-A705-957CE0C3972E` → Tenant IFX (UserTenants), Department Test (UserDepartments)
    - Set `Users.PrimaryTenantId` = IFX for that user

21. **Register in `IfxDbContext`** — add `DbSet<Tenant>` and `DbSet<Department>`

---

### Group 3 — Application Layer

**Tenant CRUD:**
22. `CreateTenantCommand` + `CreateTenantCommandHandler`
23. `UpdateTenantCommand` + `UpdateTenantCommandHandler`
24. `DeleteTenantCommand` + `DeleteTenantCommandHandler`
25. `GetAllTenantsQuery` + `GetAllTenantsQueryHandler`
26. `GetTenantByIdQuery` + `GetTenantByIdQueryHandler`
27. `TenantDto` + AutoMapper profile
28. `CreateTenantCommandValidator`, `UpdateTenantCommandValidator`

**Department CRUD:**
29. `CreateDepartmentCommand` + `CreateDepartmentCommandHandler`
30. `UpdateDepartmentCommand` + `UpdateDepartmentCommandHandler`
31. `DeleteDepartmentCommand` + `DeleteDepartmentCommandHandler`
32. `GetAllDepartmentsQuery` + `GetAllDepartmentsQueryHandler` (filter by TenantId optional)
33. `GetDepartmentByIdQuery` + `GetDepartmentByIdQueryHandler`
34. `DepartmentDto` + AutoMapper profile
35. `CreateDepartmentCommandValidator`, `UpdateDepartmentCommandValidator`

**User-Tenant / User-Department assignment:**
36. `AssignTenantToUserCommand` + handler (validates tenant exists, links user, optionally sets primary)
37. `RemoveTenantFromUserCommand` + handler
38. `AssignDepartmentToUserCommand` + handler (validates department's TenantId is in user's tenants)
39. `RemoveDepartmentFromUserCommand` + handler

**Update existing handlers:**
40. `CreateRoleCommandHandler` — pass `TenantId` from command; update `NameExistsAsync` call
41. `UpdateRoleCommandHandler` — same
42. `CreateRoleGroupCommandHandler` — same
43. `UpdateRoleGroupCommandHandler` — same
44. Update `CreateRoleCommand`, `UpdateRoleCommand` — add `TenantId` parameter
45. Update `CreateRoleGroupCommand`, `UpdateRoleGroupCommand` — add `TenantId` parameter

---

### Group 4 — Presentation Layer

**Tenant endpoints** (`/api/v1/tenant`):
46. `GET /api/v1/tenant` — `Tenant.Read`
47. `GET /api/v1/tenant/{id}` — `Tenant.Read`
48. `POST /api/v1/tenant` — `Tenant.Write`
49. `PUT /api/v1/tenant/{id}` — `Tenant.Write`
50. `DELETE /api/v1/tenant/{id}` — `Tenant.Write`

**Department endpoints** (`/api/v1/department`):
51. `GET /api/v1/department` — `Department.Read`
52. `GET /api/v1/department/{id}` — `Department.Read`
53. `POST /api/v1/department` — `Department.Write`
54. `PUT /api/v1/department/{id}` — `Department.Write`
55. `DELETE /api/v1/department/{id}` — `Department.Write`

**User management extensions:**
56. `POST /api/v1/usermanagement/users/{userId}/tenants` — `User.Write`
57. `DELETE /api/v1/usermanagement/users/{userId}/tenants/{tenantId}` — `User.Write`
58. `POST /api/v1/usermanagement/users/{userId}/departments` — `User.Write`
59. `DELETE /api/v1/usermanagement/users/{userId}/departments/{departmentId}` — `User.Write`

---

### Group 5 — Frontend

60. **`TenantManagementPage.tsx`** — list tenants, create/edit/delete modals (mirrors `RoleManagementPage`)
61. **`DepartmentManagementPage.tsx`** — list departments (with tenant filter), create/edit/delete modals
62. **API client** — add `tenantsApi` and `departmentsApi` modules
63. **Routing** — add `/tenants` and `/departments` routes, protect with `Tenant.Read`
64. **Nav** — add sidebar links for Tenants and Departments

---

### Group 6 — Tests (update existing + add new)

65. Update integration permission enforcement tests to include `/api/v1/tenant` and `/api/v1/department` in the 401/403/200 matrix
66. Add domain tests for `Tenant` and `Department` entities
67. Add application handler tests for Tenant and Department CRUD handlers
68. Add `TenantRepository` and `DepartmentRepository` infrastructure tests
69. Add frontend tests for `TenantManagementPage` and `DepartmentManagementPage`

---

## Files Checklist

### New files
- `Domain/Authorization/Tenant.cs`
- `Domain/Authorization/Department.cs`
- `Domain/Authorization/ITenantRepository.cs`
- `Domain/Authorization/IDepartmentRepository.cs`
- `Infrastructure/Authorization/Configurations/TenantConfiguration.cs`
- `Infrastructure/Authorization/Configurations/DepartmentConfiguration.cs`
- `Infrastructure/Authorization/Repositories/TenantRepository.cs`
- `Infrastructure/Authorization/Repositories/DepartmentRepository.cs`
- `Infrastructure/Persistence/Migrations/XXXXXXXX_AddMultiTenantSupport.cs`
- `Application/Authorization/Commands/CreateTenant/` (Command, Handler, Validator)
- `Application/Authorization/Commands/UpdateTenant/` (Command, Handler, Validator)
- `Application/Authorization/Commands/DeleteTenant/` (Command, Handler)
- `Application/Authorization/Queries/GetAllTenants/` (Query, Handler)
- `Application/Authorization/Queries/GetTenantById/` (Query, Handler)
- `Application/Authorization/DTOs/TenantDto.cs`
- `Application/Authorization/Commands/CreateDepartment/` (Command, Handler, Validator)
- `Application/Authorization/Commands/UpdateDepartment/` (Command, Handler, Validator)
- `Application/Authorization/Commands/DeleteDepartment/` (Command, Handler)
- `Application/Authorization/Queries/GetAllDepartments/` (Query, Handler)
- `Application/Authorization/Queries/GetDepartmentById/` (Query, Handler)
- `Application/Authorization/DTOs/DepartmentDto.cs`
- `Application/Users/Commands/AssignTenantToUser/` (Command, Handler)
- `Application/Users/Commands/RemoveTenantFromUser/` (Command, Handler)
- `Application/Users/Commands/AssignDepartmentToUser/` (Command, Handler)
- `Application/Users/Commands/RemoveDepartmentFromUser/` (Command, Handler)
- `Presentation/Authorization/TenantEndpoints.cs`
- `Presentation/Authorization/DepartmentEndpoints.cs`
- `Frontend/src/pages/TenantManagementPage.tsx`
- `Frontend/src/pages/DepartmentManagementPage.tsx`
- `Frontend/src/api/tenantsApi.ts`
- `Frontend/src/api/departmentsApi.ts`

### Modified files
- `Domain/Users/User.cs` — add PrimaryTenantId, Tenants, Departments collections
- `Domain/Authorization/Role.cs` — add TenantId
- `Domain/Authorization/RoleGroup.cs` — add TenantId
- `Domain/Identity/Idp.cs` — add TenantId
- `Domain/Authorization/IRoleRepository.cs` — update NameExistsAsync signatures
- `Domain/Authorization/IRoleGroupRepository.cs` — update NameExistsAsync signatures
- `Domain/IUnitOfWork.cs` — add Tenants, Departments
- `Infrastructure/Authorization/Configurations/RoleConfiguration.cs` — TenantId FK + unique index
- `Infrastructure/Authorization/Configurations/RoleGroupConfiguration.cs` — TenantId FK + unique index
- `Infrastructure/Identity/Configurations/IdpConfiguration.cs` — TenantId FK
- `Infrastructure/Users/Configurations/UserConfiguration.cs` — PrimaryTenantId, UserTenants, UserDepartments
- `Infrastructure/Authorization/Repositories/RoleRepository.cs` — update NameExistsAsync
- `Infrastructure/Authorization/Repositories/RoleGroupRepository.cs` — update NameExistsAsync
- `Infrastructure/Persistence/UnitOfWork.cs` — add Tenants, Departments
- `Infrastructure/Persistence/IfxDbContext.cs` — add DbSet<Tenant>, DbSet<Department>
- `Application/Authorization/Commands/CreateRole/CreateRoleCommand.cs` — add TenantId
- `Application/Authorization/Commands/UpdateRole/UpdateRoleCommand.cs` — add TenantId
- `Application/Authorization/Commands/CreateRole/CreateRoleCommandHandler.cs` — pass TenantId to NameExistsAsync
- `Application/Authorization/Commands/UpdateRole/UpdateRoleCommandHandler.cs` — same
- `Application/Authorization/Commands/CreateRoleGroup/CreateRoleGroupCommand.cs` — add TenantId
- `Application/Authorization/Commands/UpdateRoleGroup/UpdateRoleGroupCommand.cs` — add TenantId
- `Application/Authorization/Commands/CreateRoleGroup/CreateRoleGroupCommandHandler.cs` — same
- `Application/Authorization/Commands/UpdateRoleGroup/UpdateRoleGroupCommandHandler.cs` — same
- `Presentation/Authorization/RoleEndpoints.cs` — accept TenantId in create/update requests
- `Presentation/Authorization/RoleGroupEndpoints.cs` — same
- `Frontend/src/App.tsx` — add routes for Tenants, Departments
- `Frontend/src/components/Sidebar.tsx` (or nav component) — add links
- `tests/IFX.IntegrationTests/Endpoints/PermissionEnforcementTests.cs` — add tenant/department assertions

---

## Key Constraints (Do Not Violate)

1. Domain layer has zero external dependencies
2. `TenantId` on `Role`/`RoleGroup`/`Idp` must be backfilled before making NOT NULL
3. `NameExistsAsync` for roles/role groups must scope to `TenantId` after the change
4. Department-User assignment must validate that the department's `TenantId` is in the user's tenant memberships
5. Migration `Down()` must cleanly reverse all steps
6. Permission names must follow `PascalCase.PascalCase` convention
