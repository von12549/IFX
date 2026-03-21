# Plan: Permission Enforcement on All Endpoints

**Branch:** `feature/permission-enforcement`
**Date:** 2026-03-22

---

## Problem

All protected endpoints currently use only `RequireAuthorization()` — any valid bearer token grants access. No endpoint enforces a specific permission. The RBAC model (User → Roles → Permissions) exists in the database but is not enforced at the API layer.

---

## Endpoint × Permission Mapping

### Public — Anonymous (no change needed)

| Method | Route | Reason |
|--------|-------|--------|
| POST | `/api/v1/auth/register` | Unauthenticated flow |
| POST | `/api/v1/auth/confirm` | Unauthenticated flow |
| POST | `/api/v1/auth/login` | Deprecated, unauthenticated |
| POST | `/api/v1/auth/refresh` | Token refresh, AllowAnonymous |
| POST | `/api/v1/auth/revoke` | Token revoke, AllowAnonymous |
| GET  | `/api/v1/auth/oauth/authorize` | Initiates OAuth, AllowAnonymous |
| GET  | `/api/v1/auth/oauth/callback` | IdP callback, AllowAnonymous |
| GET  | `/api/v1/auth/oauth/logout` | Logout redirect, AllowAnonymous |
| GET  | `/api/v1/auth/oauth/logout-callback` | Post-logout, AllowAnonymous |
| POST | `/api/v1/auth/email/verify` | Public email verification |
| GET  | `/api/v1/auth/email/verify` | Public email link verification |

### Authenticated — Any valid token (own-data endpoints, no permission policy)

| Method | Route | Reason |
|--------|-------|--------|
| POST | `/api/v1/auth/logout` | Own session |
| GET  | `/api/v1/auth/oauth/userinfo` | Own token |
| GET  | `/api/v1/user/profile` | Own profile |
| PUT  | `/api/v1/user/profile` | Own profile |
| GET  | `/api/v1/user/login-history` | Own data |
| GET  | `/api/v1/user/activity-log` | Own data |
| POST | `/api/v1/user/sync` | Own profile sync |
| POST | `/api/v1/user/email/send-verification` | Own email |
| POST | `/api/v1/user/email/resend-verification` | Own email |
| GET  | `/api/v1/user/email/verification-status` | Own email |

### Admin — Requires specific permission

| Method | Route | Required Permission |
|--------|-------|-------------------|
| GET    | `/api/v1/usermanagement/users` | `User.Read` |
| GET    | `/api/v1/usermanagement/users/{userId}` | `User.Read` |
| PUT    | `/api/v1/usermanagement/users/{userId}` | `User.Write` |
| POST   | `/api/v1/usermanagement/users/{userId}/send-test-email` | `User.Write` |
| POST   | `/api/v1/usermanagement/users/{userId}/roles` | `User.Write` |
| DELETE | `/api/v1/usermanagement/users/{userId}/roles/{roleId}` | `User.Write` |
| POST   | `/api/v1/usermanagement/users/{userId}/rolegroups` | `User.Write` |
| DELETE | `/api/v1/usermanagement/users/{userId}/rolegroups/{roleGroupId}` | `User.Write` |
| GET    | `/api/v1/role` | `Role.Read` |
| GET    | `/api/v1/role/{roleId}` | `Role.Read` |
| POST   | `/api/v1/role` | `Role.Write` |
| PUT    | `/api/v1/role/{roleId}` | `Role.Write` |
| DELETE | `/api/v1/role/{roleId}` | `Role.Write` |
| POST   | `/api/v1/role/{roleId}/permissions` | `Role.Write` |
| DELETE | `/api/v1/role/{roleId}/permissions/{permissionId}` | `Role.Write` |
| GET    | `/api/v1/rolegroup` | `RoleGroup.Read` |
| POST   | `/api/v1/rolegroup` | `RoleGroup.Write` |
| PUT    | `/api/v1/rolegroup/{roleGroupId}` | `RoleGroup.Write` |
| DELETE | `/api/v1/rolegroup/{roleGroupId}` | `RoleGroup.Write` |
| POST   | `/api/v1/rolegroup/{roleGroupId}/roles` | `RoleGroup.Write` |
| DELETE | `/api/v1/rolegroup/{roleGroupId}/roles/{roleId}` | `RoleGroup.Write` |
| GET    | `/api/v1/permission` | `Permission.Read` |
| POST   | `/api/v1/permission` | `Permission.Write` |
| PUT    | `/api/v1/permission/{permissionId}` | `Permission.Write` |
| DELETE | `/api/v1/permission/{permissionId}` | `Permission.Write` |
| GET    | `/api/v1/idp` | `Idp.Read` |
| GET    | `/api/v1/idp/{idpId}` | `Idp.Read` |
| POST   | `/api/v1/idp` | `Idp.Write` |
| PUT    | `/api/v1/idp/{idpId}` | `Idp.Write` |

### Existing Permissions in Database

Seeded by `AddRbacRoleGroupsAndPermissions` migration:

| Permission Name | Description |
|----------------|-------------|
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

All 10 permissions are already in the database and assigned to the `Admin` role. No new permissions or seed data are needed.

---

## Implementation Approach

### Layer: Infrastructure (new)

**`PermissionRequirement : IAuthorizationRequirement`**
- Holds a single `string PermissionName`

**`PermissionAuthorizationHandler : AuthorizationHandler<PermissionRequirement>`**
- Reads `(issuer, subject)` from JWT claims
- Calls `IUnitOfWork.Users.GetByIssuerAndSubjectWithPermissionsAsync(issuer, subject)` (already exists)
- Flattens permissions from direct roles + role groups → roles → permissions
- Succeeds if the user has the required permission name

**`PermissionAuthorizationPolicyProvider : DefaultAuthorizationPolicyProvider`**
- On-demand policy creation: if policy name matches a known permission (e.g. `"User.Read"`), returns a policy with `PermissionRequirement`
- Falls back to `base` for built-in policies

### Layer: Presentation (extension method)

**`RouteHandlerBuilderExtensions.RequirePermission(string permissionName)`**
- Calls `.RequireAuthorization(permissionName)` — the policy provider handles the rest

### Layer: ApiHost

Register in `Program.cs`:
- `services.AddSingleton<IAuthorizationPolicyProvider, PermissionAuthorizationPolicyProvider>()`
- `services.AddScoped<IAuthorizationHandler, PermissionAuthorizationHandler>()`

### Endpoint changes

Replace `RequireAuthorization()` with `RequirePermission("Permission.Name")` in each endpoint extension file per the mapping table above. Group-level `RequireAuthorization()` stays; individual endpoints add the more specific permission requirement.

---

## Implementation Order

1. `PermissionRequirement` — trivial record
2. `PermissionAuthorizationHandler` — DB lookup + claim extraction
3. `PermissionAuthorizationPolicyProvider` — on-demand policy creation
4. `RouteHandlerBuilderExtensions.RequirePermission()`
5. Register in `Program.cs`
6. Update all 9 endpoint extension files
7. Add/update integration tests for permission enforcement
8. Update `Produces` responses to include `403 Forbidden` where missing

---

## Files to Create

| File | Location |
|------|----------|
| `PermissionRequirement.cs` | `Auth.Infrastructure/Authorization/` |
| `PermissionAuthorizationHandler.cs` | `Auth.Infrastructure/Authorization/` |
| `PermissionAuthorizationPolicyProvider.cs` | `Auth.Infrastructure/Authorization/` |
| `RouteHandlerBuilderExtensions.cs` | `Auth.Presentation/Extensions/` |

## Files to Modify

| File | Change |
|------|--------|
| `Program.cs` | Register handler + policy provider |
| `AuthServiceCollectionExtensions.cs` (if exists) | Or add DI registration here |
| `PermissionEndpointExtensions.cs` | Add `RequirePermission` per route |
| `RoleEndpointExtensions.cs` | Add `RequirePermission` per route |
| `RoleGroupEndpointExtensions.cs` | Add `RequirePermission` per route |
| `IdpEndpointExtensions.cs` | Add `RequirePermission` per route |
| `UserManagementEndpointExtensions.cs` | Add `RequirePermission` per route |

---

## Non-Goals

- Embedding permissions in JWT tokens (would require Cognito Lambda trigger)
- Caching per-request permission lookups (out of scope; `GetByIssuerAndSubjectWithPermissionsAsync` is already efficient)
- UI changes (frontend already shows/hides based on user roles, enforcement is backend-only)
