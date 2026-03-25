# Plan: RBAC Redesign — Role Groups, Roles, and Permissions

**Date:** 2026-03-20
**Branch:** `feature/rbac-role-groups-permissions`
**Status:** Implemented
**Base:** `main`

---

## Goal

Upgrade the current simple RBAC (User → single Role) to a full RBAC model with:

- **RoleGroup** — named collections of Roles
- **Role** — named sets of Permissions (entity renamed from `UserRole`)
- **Permission** — granular action tokens (e.g. `User.Read`, `Role.Write`)

Authorization logic changes from **require Role** to **require Permission**, computed as:

```
effectivePermissions =
  union(User.DirectRoles, User.RoleGroups.SelectMany(g => g.Roles))
  .SelectMany(r => r.Permissions)
  .Distinct()
```

All endpoint policy checks are removed in this plan (to be re-added in a future plan).

---

## Current State

- `UserRole` entity — role reference table (`auth.UserRoles`), columns: `Id`, `RoleName`, `Description`
- `User` entity — has single `UserRoleId` FK (many-to-one)
- `UserAuthResult` DTO — has single `string RoleName` property
- `GetOrProvisionUserQueryHandler` — loads `user.UserRole.RoleName` (single nav), returns single role
- `UserRoleClaimsTransformation` (ApiHost) — adds one `ClaimTypes.Role` claim from `result.Value.RoleName`
- Endpoints use `.RequireAuthorization(policy => policy.RequireRole("Admin"))`
- Seed data: 4 roles — `Admin`, `User`, `SsoUser`, `PendingUser`

---

## New Data Model

### New Entities

| Entity | Table | Columns |
|---|---|---|
| `Role` | `auth.Roles` | Id, Name, Description, CreatedAt, UpdatedAt |
| `RoleGroup` | `auth.RoleGroups` | Id, Name, Description, CreatedAt, UpdatedAt |
| `Permission` | `auth.Permissions` | Id, Name, Description, CreatedAt, UpdatedAt |

### New Join Tables

| Table | Purpose |
|---|---|
| `auth.UserRoles` | User ↔ Role (many-to-many, join only) |
| `auth.UserRoleGroups` | User ↔ RoleGroup (many-to-many) |
| `auth.RoleGroupRoles` | RoleGroup ↔ Role (many-to-many) |
| `auth.RolePermissions` | Role ↔ Permission (many-to-many) |

> **Note:** The old `auth.UserRoles` table (role definitions) is renamed to `auth.Roles`.
> The new `auth.UserRoles` is the User↔Role join table (composite PK: UserId + RoleId).

### Renamed / Removed

| Before | After | Reason |
|---|---|---|
| `UserRole` entity | `Role` | Cleaner name; join table separation makes `UserRole` ambiguous |
| `User.UserRoleId` (FK column) | removed | Replaced by many-to-many |
| `User.UserRole` navigation | `User.Roles`, `User.RoleGroups` | Many-to-many collections |
| `IUserRoleRepository` | `IRoleRepository` | Matches renamed entity |

---

## Seed Data

### Permissions (10 records)

| Name | Description |
|---|---|
| `User.Read` | View user data |
| `User.Write` | Create/update user data |
| `Role.Read` | View roles |
| `Role.Write` | Create/update roles |
| `RoleGroup.Read` | View role groups |
| `RoleGroup.Write` | Create/update role groups |
| `Permission.Read` | View permissions |
| `Permission.Write` | Create/update permissions |
| `Idp.Read` | View identity providers |
| `Idp.Write` | Create/update identity providers |

### Role → Permission Assignments

| Role | Permissions |
|---|---|
| `Admin` | All 10 permissions |
| `User` | `User.Read`, `User.Write` |
| `SsoUser` | `User.Read` |
| `PendingUser` | `User.Read` |

### RoleGroups

| Name | Roles |
|---|---|
| `TestGroup` | `Admin`, `User`, `SsoUser` |

---

## Endpoints

### Existing Role endpoints — policy checks removed, Delete added

| Method | Path | Action | Change |
|---|---|---|---|
| `GET` | `/api/v1/role` | GetAllRoles | Remove policy check |
| `POST` | `/api/v1/role` | CreateRole | Renamed from AddRole; remove policy check |
| `PUT` | `/api/v1/role/{roleId}` | UpdateRole | Remove policy check |
| `DELETE` | `/api/v1/role/{roleId}` | DeleteRole | New endpoint |
| `POST` | `/api/v1/role/{roleId}/permissions` | AssignPermissionsToRole | New endpoint |
| `DELETE` | `/api/v1/role/{roleId}/permissions/{permissionId}` | RemovePermissionFromRole | New endpoint |

### New Permission endpoints

| Method | Path | Action |
|---|---|---|
| `GET` | `/api/v1/permission` | GetAllPermissions |
| `POST` | `/api/v1/permission` | CreatePermission |
| `PUT` | `/api/v1/permission/{permissionId}` | UpdatePermission |
| `DELETE` | `/api/v1/permission/{permissionId}` | DeletePermission |

### New RoleGroup endpoints

| Method | Path | Action |
|---|---|---|
| `GET` | `/api/v1/rolegroup` | GetAllRoleGroups |
| `POST` | `/api/v1/rolegroup` | CreateRoleGroup |
| `PUT` | `/api/v1/rolegroup/{roleGroupId}` | UpdateRoleGroup |
| `DELETE` | `/api/v1/rolegroup/{roleGroupId}` | DeleteRoleGroup |
| `POST` | `/api/v1/rolegroup/{roleGroupId}/roles` | AssignRolesToRoleGroup |
| `DELETE` | `/api/v1/rolegroup/{roleGroupId}/roles/{roleId}` | RemoveRoleFromRoleGroup |

### User assignment endpoints (extend UserManagement)

| Method | Path | Action |
|---|---|---|
| `POST` | `/api/v1/usermanagement/{userId}/roles` | AssignRolesToUser |
| `DELETE` | `/api/v1/usermanagement/{userId}/roles/{roleId}` | RemoveRoleFromUser |
| `POST` | `/api/v1/usermanagement/{userId}/rolegroups` | AssignRoleGroupsToUser |
| `DELETE` | `/api/v1/usermanagement/{userId}/rolegroups/{roleGroupId}` | RemoveRoleGroupFromUser |

### Remove all policy checks from existing endpoints

All existing `.RequireAuthorization(policy => policy.RequireRole(...))` calls are replaced with `.RequireAuthorization()` (authentication required, no role/permission check).

Affected:
- `RoleEndpointExtensions`
- `UserManagementEndpointExtensions`
- `IdpEndpointExtensions`

---

## Implementation Steps

Execute in this order to keep the solution compiling at each step.

### Step 1 — Domain layer

**a. Rename `UserRole` → `Role`**
- `Authorization/UserRole.cs` → `Authorization/Role.cs`
- Class: `UserRole` → `Role`
- Rename property `RoleName` → `Name`
- Add navigation: `private readonly List<Permission> _permissions = new(); public IReadOnlyCollection<Permission> Permissions => _permissions.AsReadOnly();`
- Add domain methods: `AddPermission(Permission p)`, `RemovePermission(Guid permissionId)`

**b. Add `Permission` entity** — `Authorization/Permission.cs`
```csharp
public class Permission : BaseEntity, IAuditableEntity
{
    public string Name { get; private set; }
    public string Description { get; private set; }
    public DateTime CreatedAt { get; set; }
    public DateTime UpdatedAt { get; set; }
    public static Permission Create(string name, string description) { ... }
    public void Update(string name, string description) { ... }
}
```

**c. Add `RoleGroup` entity** — `Authorization/RoleGroup.cs`
```csharp
public class RoleGroup : BaseEntity, IAuditableEntity
{
    public string Name { get; private set; }
    public string Description { get; private set; }
    public DateTime CreatedAt { get; set; }
    public DateTime UpdatedAt { get; set; }
    private readonly List<Role> _roles = new();
    public IReadOnlyCollection<Role> Roles => _roles.AsReadOnly();
    public static RoleGroup Create(string name, string description) { ... }
    public void Update(string name, string description) { ... }
    public void AddRole(Role role) { ... }
    public void RemoveRole(Guid roleId) { ... }
}
```

**d. Update `User` entity**
- Remove `UserRoleId` property and `UserRole` navigation
- Add: `private readonly List<Role> _roles = new(); public IReadOnlyCollection<Role> Roles => _roles.AsReadOnly();`
- Add: `private readonly List<RoleGroup> _roleGroups = new(); public IReadOnlyCollection<RoleGroup> RoleGroups => _roleGroups.AsReadOnly();`
- Replace `AssignRole(Guid roleId)` with `AddRole(Role role)`, `RemoveRole(Guid roleId)`
- Add: `AddRoleGroup(RoleGroup group)`, `RemoveRoleGroup(Guid groupId)`
- Update `Create(...)` factory — remove `userRoleId` parameter

**e. Update `IUserRoleRepository` → `IRoleRepository`** — `Authorization/IRoleRepository.cs`
```csharp
Task<Role?> GetByIdAsync(Guid id, CancellationToken ct = default);
Task<Role?> GetByNameAsync(string name, CancellationToken ct = default);
Task<Role?> GetByIdWithPermissionsAsync(Guid id, CancellationToken ct = default);
Task<List<Role>> GetAllAsync(CancellationToken ct = default);
Task AddAsync(Role role, CancellationToken ct = default);
Task<bool> NameExistsAsync(string name, CancellationToken ct = default);
Task<bool> NameExistsAsync(string name, Guid excludeId, CancellationToken ct = default);
void Remove(Role role);
```

**f. Add `IPermissionRepository`** — `Authorization/IPermissionRepository.cs`
```csharp
Task<Permission?> GetByIdAsync(Guid id, CancellationToken ct = default);
Task<Permission?> GetByNameAsync(string name, CancellationToken ct = default);
Task<List<Permission>> GetAllAsync(CancellationToken ct = default);
Task AddAsync(Permission permission, CancellationToken ct = default);
Task<bool> NameExistsAsync(string name, CancellationToken ct = default);
Task<bool> NameExistsAsync(string name, Guid excludeId, CancellationToken ct = default);
void Remove(Permission permission);
```

**g. Add `IRoleGroupRepository`** — `Authorization/IRoleGroupRepository.cs`
```csharp
Task<RoleGroup?> GetByIdAsync(Guid id, CancellationToken ct = default);
Task<RoleGroup?> GetByNameAsync(string name, CancellationToken ct = default);
Task<RoleGroup?> GetByIdWithRolesAsync(Guid id, CancellationToken ct = default);
Task<List<RoleGroup>> GetAllAsync(CancellationToken ct = default);
Task AddAsync(RoleGroup group, CancellationToken ct = default);
Task<bool> NameExistsAsync(string name, CancellationToken ct = default);
Task<bool> NameExistsAsync(string name, Guid excludeId, CancellationToken ct = default);
void Remove(RoleGroup group);
```

**h. Update `IUserRepository`** — add:
```csharp
Task<User?> GetByIdWithRolesAndGroupsAsync(Guid id, CancellationToken ct = default);
// Eager-loads Roles.Permissions and RoleGroups.Roles.Permissions
Task<User?> GetByIssuerAndSubjectWithPermissionsAsync(string issuer, string subject, CancellationToken ct = default);
```

---

### Step 2 — Application layer

**a. DTOs**

Update `UserRoleDto` → `RoleDto`:
```csharp
public class RoleDto { public Guid Id; public string Name; public string Description; }
```

Add `PermissionDto`:
```csharp
public class PermissionDto { public Guid Id; public string Name; public string Description; }
```

Add `RoleGroupDto`:
```csharp
public class RoleGroupDto { public Guid Id; public string Name; public string Description; public List<RoleDto> Roles; }
```

Add `RoleDetailDto`:
```csharp
public class RoleDetailDto { public Guid Id; public string Name; public string Description; public List<PermissionDto> Permissions; }
```

Update `UserAuthResult` — replace single `string RoleName` with `List<string> PermissionNames`:
```csharp
public class UserAuthResult
{
    public Guid UserId { get; init; }
    public List<string> PermissionNames { get; init; } = [];
    public bool WasProvisioned { get; init; }
}
```

**b. Role Commands**

Rename `AddRoleCommand` → `CreateRoleCommand`, update field `RoleName` → `Name`:
- `CreateRoleCommand(string Name, string Description)`
- `CreateRoleCommandHandler` — uses `IRoleRepository`

Update `UpdateRoleCommand` field `RoleName` → `Name`.

Add new commands:
- `DeleteRoleCommand(Guid RoleId)`
- `AssignPermissionsToRoleCommand(Guid RoleId, List<Guid> PermissionIds)`
- `RemovePermissionFromRoleCommand(Guid RoleId, Guid PermissionId)`

**c. Permission Commands** (new, in `Authorization/Commands/`)
- `CreatePermissionCommand(string Name, string Description)` + handler
- `UpdatePermissionCommand(Guid PermissionId, string Name, string Description)` + handler
- `DeletePermissionCommand(Guid PermissionId)` + handler

**d. RoleGroup Commands** (new, in `Authorization/Commands/`)
- `CreateRoleGroupCommand(string Name, string Description)` + handler
- `UpdateRoleGroupCommand(Guid RoleGroupId, string Name, string Description)` + handler
- `DeleteRoleGroupCommand(Guid RoleGroupId)` + handler
- `AssignRolesToRoleGroupCommand(Guid RoleGroupId, List<Guid> RoleIds)` + handler
- `RemoveRoleFromRoleGroupCommand(Guid RoleGroupId, Guid RoleId)` + handler

**e. User Assignment Commands** (new, in `Users/Commands/`)
- `AssignRolesToUserCommand(Guid UserId, List<Guid> RoleIds)` + handler
- `RemoveRoleFromUserCommand(Guid UserId, Guid RoleId)` + handler
- `AssignRoleGroupsToUserCommand(Guid UserId, List<Guid> RoleGroupIds)` + handler
- `RemoveRoleGroupFromUserCommand(Guid UserId, Guid RoleGroupId)` + handler

**f. Queries**

Update `GetAllRolesQuery` → returns `List<RoleDto>` (field rename `RoleName` → `Name`).

Add:
- `GetRoleByIdQuery(Guid RoleId)` → `RoleDetailDto`
- `GetAllPermissionsQuery` → `List<PermissionDto>`
- `GetAllRoleGroupsQuery` → `List<RoleGroupDto>`

**g. Update `GetOrProvisionUserQueryHandler`**

For the **existing user path** (line 47–66), replace:
```csharp
// OLD
if (user.UserRole == null) return failure;
return Result<UserAuthResult>.Success(new UserAuthResult { RoleName = user.UserRole.RoleName, ... });
```
With:
```csharp
// NEW — compute effective permissions
var permissions = user.Roles
    .Concat(user.RoleGroups.SelectMany(g => g.Roles))
    .SelectMany(r => r.Permissions)
    .Select(p => p.Name)
    .Distinct()
    .ToList();

return Result<UserAuthResult>.Success(new UserAuthResult
{
    UserId = user.Id,
    PermissionNames = permissions,
    WasProvisioned = false
});
```

Requires using `GetByIssuerAndSubjectWithPermissionsAsync` (new repo method that eager-loads roles+groups+permissions).

For the **provisioned user path** (line 176–181), `ProvisionSsoUserResponse` must also return `List<string> PermissionNames` so `UserAuthResult` can be populated.

**h. Update `ProvisionSsoUserCommandHandler`**

After creating and saving the user, load their assigned role's permissions and return them in `ProvisionSsoUserResponse`.

Update `ProvisionSsoUserResponse`:
```csharp
public record ProvisionSsoUserResponse(Guid UserId, List<string> PermissionNames, bool WasProvisioned);
```

**i. Update `MappingProfile`**
- `Role` → `RoleDto` (map `Name`)
- `Permission` → `PermissionDto`
- `RoleGroup` → `RoleGroupDto` (include `Roles`)
- `Role` → `RoleDetailDto` (include `Permissions`)

---

### Step 3 — Infrastructure layer

**a. EF Configurations**

Rename `UserRoleConfiguration` → `RoleConfiguration`:
- Table: `"UserRoles"` → `"Roles"`
- Column: `RoleName` → `Name`
- Add many-to-many to `Permissions` via `auth.RolePermissions`:
  ```csharp
  builder.HasMany(r => r.Permissions)
      .WithMany()
      .UsingEntity(j => j.ToTable("RolePermissions", "auth"));
  ```

Add `PermissionConfiguration`:
- Table: `auth.Permissions`
- Unique index on `Name`

Add `RoleGroupConfiguration`:
- Table: `auth.RoleGroups`
- Unique index on `Name`
- Many-to-many `Roles` via `auth.RoleGroupRoles`

Update `UserConfiguration`:
- Remove `UserRoleId` FK
- Add many-to-many to `Roles` via `auth.UserRoles`
- Add many-to-many to `RoleGroups` via `auth.UserRoleGroups`

**b. Update `IfxDbContext`**
- Replace `DbSet<UserRole>` → `DbSet<Role>`
- Add `DbSet<Permission> Permissions`
- Add `DbSet<RoleGroup> RoleGroups`
- Update `OnModelCreating` — apply new configurations

**c. Repositories**

Rename `UserRoleRepository` → `RoleRepository`, implement `IRoleRepository`.
Add `PermissionRepository`, `RoleGroupRepository`.
Update `UserRepository` — implement new eager-load methods.

**d. EF Core Migration**

```bash
cd src/Modules/Auth/IFX.Modules.Auth.Infrastructure
dotnet ef migrations add AddRbacRoleGroupsAndPermissions --startup-project ../../../ApiHost/IFX.ApiHost
```

Migration `Up()` order:
1. Rename table `auth.UserRoles` → `auth.Roles`, column `RoleName` → `Name`
2. Drop `Users.UserRoleId` FK constraint and column
3. Create `auth.Permissions` table
4. Create `auth.RoleGroups` table
5. Create `auth.UserRoles` join table (UserId PK + RoleId PK)
6. Create `auth.UserRoleGroups` join table (UserId + RoleGroupId)
7. Create `auth.RoleGroupRoles` join table (RoleGroupId + RoleId)
8. Create `auth.RolePermissions` join table (RoleId + PermissionId)
9. Seed 10 Permissions
10. Seed Role→Permission assignments (16 records)
11. Seed 1 RoleGroup (TestGroup)
12. Seed RoleGroupRoles (TestGroup → Admin, User, SsoUser)

**e. Update `DependencyInjection.cs`**
- Replace `IUserRoleRepository`/`UserRoleRepository` with `IRoleRepository`/`RoleRepository`
- Add `IPermissionRepository`/`PermissionRepository`
- Add `IRoleGroupRepository`/`RoleGroupRepository`

---

### Step 4 — ApiHost: `UserRoleClaimsTransformation` → `UserPermissionClaimsTransformation`

This is a **critical change**. The transformation currently adds a single `ClaimTypes.Role` claim. With the new design, it adds permission claims.

Rename file and class:
- `Authorization/UserRoleClaimsTransformation.cs` → `Authorization/UserPermissionClaimsTransformation.cs`
- Class: `UserRoleClaimsTransformation` → `UserPermissionClaimsTransformation`
- Update registration in `AuthenticationConfiguration.cs` (or wherever `IClaimsTransformation` is registered)

**a. Change guard clause (line 32)**

Old:
```csharp
if (principal.HasClaim(c => c.Type == ClaimTypes.Role))
```
New:
```csharp
if (principal.HasClaim(c => c.Type == "user_id"))
```

**b. Change claim emission (line 82–85)**

Old:
```csharp
var identity = new ClaimsIdentity();
identity.AddClaim(new Claim(ClaimTypes.Role, result.Value!.RoleName));
identity.AddClaim(new Claim("user_id", result.Value.UserId.ToString()));
principal.AddIdentity(identity);
```
New:
```csharp
var identity = new ClaimsIdentity();
identity.AddClaim(new Claim("user_id", result.Value!.UserId.ToString()));
foreach (var permission in result.Value.PermissionNames)
{
    identity.AddClaim(new Claim("permission", permission));
}
principal.AddIdentity(identity);
```

**c. Update log message (line 82)**

Old: `"User {Issuer}/{Subject} has no role assigned"`
New: (handled by `PermissionNames` being empty — warn if empty)

---

### Step 5 — Presentation layer

**a. Role endpoints** (`Authorization/Endpoints/RoleEndpoints.cs`)
- Remove `.RequireAuthorization(policy => policy.RequireRole("Admin"))` → `.RequireAuthorization()`
- Rename `AddRole` → `CreateRole`
- Add `DeleteRole` handler
- Add `AssignPermissionsToRole`, `RemovePermissionFromRole` handlers

**b. New Permission endpoints**
- `Authorization/Endpoints/PermissionEndpoints.cs`
- `Authorization/Endpoints/PermissionEndpointExtensions.cs`
- New requests: `CreatePermissionRequest`, `UpdatePermissionRequest`
- Routes under `/api/v1/permission`

**c. New RoleGroup endpoints**
- `Authorization/Endpoints/RoleGroupEndpoints.cs`
- `Authorization/Endpoints/RoleGroupEndpointExtensions.cs`
- New requests: `CreateRoleGroupRequest`, `UpdateRoleGroupRequest`, `AssignRolesToRoleGroupRequest`
- Routes under `/api/v1/rolegroup`

**d. User assignment endpoints** — extend `UserManagementEndpoints.cs` and `UserManagementEndpointExtensions.cs`
- New requests: `AssignRolesToUserRequest`, `AssignRoleGroupsToUserRequest`

**e. Remove all policy checks from all existing endpoints**
- `RoleEndpointExtensions` — remove `RequireRole("Admin")`
- `UserManagementEndpointExtensions` — remove role policy
- `IdpEndpointExtensions` — remove role policy

---

### Step 6 — Composition layer

Register new endpoint mappers in `DependencyInjection.cs`:
```csharp
app.MapPermissionEndpoints();
app.MapRoleGroupEndpoints();
// UserManagement already registered; new user-assignment endpoints added inside
```

---

### Step 7 — Tests

Update all references to:
- `UserRole` → `Role`
- `UserRoleDto` → `RoleDto`
- `IUserRoleRepository` → `IRoleRepository`
- `UserRoleId` (in test builders/fixtures) → use `AddRole(role)`
- `UserAuthResult.RoleName` → `UserAuthResult.PermissionNames`
- `RoleName` field in DTOs → `Name`

Add tests for new commands/queries as appropriate.

---

### Step 8 — Full verification

```bash
dotnet build IFX.sln
dotnet test IFX.sln
```

---

## File Rename Summary

| Old | New |
|---|---|
| `Domain/Authorization/UserRole.cs` | `Domain/Authorization/Role.cs` |
| `Domain/Authorization/IUserRoleRepository.cs` | `Domain/Authorization/IRoleRepository.cs` |
| `Infrastructure/Authorization/Configurations/UserRoleConfiguration.cs` | `Infrastructure/Authorization/Configurations/RoleConfiguration.cs` |
| `Infrastructure/Authorization/Repositories/UserRoleRepository.cs` | `Infrastructure/Authorization/Repositories/RoleRepository.cs` |
| `Application/Authorization/DTOs/UserRoleDto.cs` | `Application/Authorization/DTOs/RoleDto.cs` |
| `Application/Authorization/Commands/AddRole/` | `Application/Authorization/Commands/CreateRole/` |
| `Presentation/Authorization/Requests/AddRoleRequest.cs` | `Presentation/Authorization/Requests/CreateRoleRequest.cs` |
| `ApiHost/Authorization/UserRoleClaimsTransformation.cs` | `ApiHost/Authorization/UserPermissionClaimsTransformation.cs` |

---

## Risk Areas

| Risk | Mitigation |
|---|---|
| `UserRoleClaimsTransformation` adds single `ClaimTypes.Role` — all existing role checks break | Update transformation to emit `"permission"` claims; remove all policy checks from endpoints |
| `GetOrProvisionUserQueryHandler` uses `user.UserRole` (single nav, can be null) | Replace with `GetByIssuerAndSubjectWithPermissionsAsync`; handle empty permission list gracefully |
| `ProvisionSsoUserCommandHandler` sets `User.Create(userRoleId, ...)` | Update to `User.Create(displayName)` + `user.AddRole(role)` after role lookup |
| Table rename `auth.UserRoles` (role defs) → `auth.Roles` + new `auth.UserRoles` (join) | Careful migration ordering: rename first, then create new join table |
| EF migration `Down()` must reverse seed data and table recreations | Write explicit `Down()` — do not rely on auto-generation |
| Tests that create `User` with `UserRoleId` will fail to compile | Scan test projects for `UserRoleId`, `UserRole` before finalizing |
| Existing JWTs in circulation have `ClaimTypes.Role` | `UserRoleClaimsTransformation` guard changes from `ClaimTypes.Role` to `user_id`; old tokens re-transform on next request and get new permission claims — no issue |
