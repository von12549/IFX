# Plan: Refactor Authorization Subdomain into Feature Subfolders

**Date:** 2026-03-26
**Branch:** `feature/abac/scope-globalroles`
**Status:** Implemented
**Scope:** `Auth.Application/Authorization/` only — no behavior changes, no new projects.

---

## Goal

Normalize the flat `Authorization/` structure inside `Auth.Application` into feature-specific subfolders, matching the pattern already used by `Policies/` and `GlobalRoles/`.

**Before (flat):**
```
Authorization/
  Commands/
    CreateRole/  CreateRoleGroup/  CreatePermission/
    CreateTenant/  CreateDepartment/  ... (all features mixed)
  Queries/
    GetAllRoles/  GetAllRoleGroups/  ... (all features mixed)
  DTOs/
    RoleDto.cs  RoleGroupDto.cs  PermissionDto.cs  TenantDto.cs  DepartmentDto.cs  ...
  Authorization/
    RoleResourceAttributes.cs  RoleGroupResourceAttributes.cs  DepartmentResourceAttributes.cs
```

**After (feature subfolders):**
```
Authorization/
  Roles/
    Commands/  CreateRole/  UpdateRole/  DeleteRole/  AssignPermissionsToRole/  RemovePermissionFromRole/
    Queries/   GetAllRoles/  GetRoleById/
    DTOs/      RoleDto.cs  RoleDetailDto.cs
    Authorization/  RoleResourceAttributes.cs
  RoleGroups/
    Commands/  CreateRoleGroup/  UpdateRoleGroup/  DeleteRoleGroup/  AssignRolesToRoleGroup/  RemoveRoleFromRoleGroup/
    Queries/   GetAllRoleGroups/
    DTOs/      RoleGroupDto.cs
    Authorization/  RoleGroupResourceAttributes.cs
  Permissions/
    Commands/  CreatePermission/  UpdatePermission/  DeletePermission/
    Queries/   GetAllPermissions/
    DTOs/      PermissionDto.cs
  Tenants/
    Commands/  CreateTenant/  UpdateTenant/  DeleteTenant/
    Queries/   GetAllTenants/  GetTenantById/
    DTOs/      TenantDto.cs
  Departments/
    Commands/  CreateDepartment/  UpdateDepartment/  DeleteDepartment/
    Queries/   GetAllDepartments/  GetDepartmentById/
    DTOs/      DepartmentDto.cs
    Authorization/  DepartmentResourceAttributes.cs
  Policies/          ← pre-existing, unchanged
  GlobalRoles/       ← pre-existing, unchanged
```

---

## Namespace Changes

| Old | New |
|-----|-----|
| `...Authorization.Commands.CreateRole` | `...Authorization.Roles.Commands.CreateRole` |
| `...Authorization.Commands.CreateRoleGroup` | `...Authorization.RoleGroups.Commands.CreateRoleGroup` |
| `...Authorization.Commands.CreatePermission` | `...Authorization.Permissions.Commands.CreatePermission` |
| `...Authorization.Commands.CreateTenant` | `...Authorization.Tenants.Commands.CreateTenant` |
| `...Authorization.Commands.CreateDepartment` | `...Authorization.Departments.Commands.CreateDepartment` |
| `...Authorization.Queries.GetAllRoles` | `...Authorization.Roles.Queries.GetAllRoles` |
| `...Authorization.Queries.GetRoleById` | `...Authorization.Roles.Queries.GetRoleById` |
| `...Authorization.Queries.GetAllRoleGroups` | `...Authorization.RoleGroups.Queries.GetAllRoleGroups` |
| `...Authorization.Queries.GetAllPermissions` | `...Authorization.Permissions.Queries.GetAllPermissions` |
| `...Authorization.Queries.GetAllTenants` | `...Authorization.Tenants.Queries.GetAllTenants` |
| `...Authorization.Queries.GetTenantById` | `...Authorization.Tenants.Queries.GetTenantById` |
| `...Authorization.Queries.GetAllDepartments` | `...Authorization.Departments.Queries.GetAllDepartments` |
| `...Authorization.Queries.GetDepartmentById` | `...Authorization.Departments.Queries.GetDepartmentById` |
| `...Authorization.DTOs` | `...Authorization.{Feature}.DTOs` |
| `...Authorization.Authorization` | `...Authorization.{Feature}.Authorization` |

---

## Cross-DTO Dependencies

`RoleDetailDto` references `PermissionDto` — requires:
```csharp
using IFX.Modules.Auth.Application.Authorization.Permissions.DTOs;
```

`RoleGroupDto` references `RoleDto` — requires:
```csharp
using IFX.Modules.Auth.Application.Authorization.Roles.DTOs;
```

---

## Consuming Files Updated

| File | Change |
|------|--------|
| `Application/Mappings/MappingProfile.cs` | 1 using → 5 feature-specific usings |
| `Application/Users/DTOs/UserProfileDto.cs` | 1 using → 4 feature-specific usings |
| `Presentation/Authorization/Endpoints/RoleEndpoints.cs` | Updated usings |
| `Presentation/Authorization/Endpoints/RoleGroupEndpoints.cs` | Updated usings |
| `Presentation/Authorization/Endpoints/PermissionEndpoints.cs` | Updated usings |
| `Presentation/Authorization/Endpoints/TenantEndpoints.cs` | Updated usings |
| `Presentation/Authorization/Endpoints/DepartmentEndpoints.cs` | Updated usings |
| 20 test files in `Auth.Application.Tests/` | Updated usings |

---

## Constraints

- No behavior changes — pure structural reorganization
- No new projects
- `Policies/` and `GlobalRoles/` subfolders untouched (already feature-structured)
- Cross-subdomain `using` references within the same project are permitted
