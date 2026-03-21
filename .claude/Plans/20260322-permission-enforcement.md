# Plan: Permission Enforcement on All Endpoints

**Branch:** `feature/permission-enforcement`
**Date:** 2026-03-22
**Updated:** 2026-03-22

---

## Problem

All protected endpoints currently use only `RequireAuthorization()` — any valid bearer token grants access. No endpoint enforces a specific permission. The RBAC model (User → Roles → Permissions) exists in the database and is already loaded per-request, but is not checked at the endpoint level.

---

## Existing Infrastructure: `UserPermissionClaimsTransformation`

**`ApiHost/Authorization/UserPermissionClaimsTransformation.cs`** already runs on every authenticated request via `IClaimsTransformation`. It:

1. Extracts `(issuer, subject)` from the JWT
2. Calls `GetOrProvisionUserQuery` — fetches the user from DB and handles SSO auto-provisioning
3. Adds `Claim("user_id", ...)` and one `Claim("permission", "X.Y")` per permission the user holds (via roles + role groups)

This means **permission data is already on the `ClaimsPrincipal` before any authorization handler runs**. The `PermissionAuthorizationHandler` must read claims only — no additional DB call is needed or wanted.

Removing or modifying this class is **out of scope** — it also drives the auto-provisioning flow for SSO users.

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

### Request Flow (after implementation)

```
HTTP Request
  → JWT validation (DynamicJwtBearerEvents)
  → UserPermissionClaimsTransformation.TransformAsync()
      → GetOrProvisionUserQuery (DB fetch + SSO auto-provision)
      → Adds Claim("permission", "User.Read"), Claim("permission", "Role.Write"), …
  → PermissionAuthorizationHandler.HandleRequirementAsync()
      → context.User.HasClaim("permission", requirement.PermissionName)   ← claims only, no DB
      → Succeed or Fail (403)
  → Endpoint handler
```

### New: `PermissionRequirement`

Location: `Auth.Infrastructure/Authorization/PermissionRequirement.cs`

```csharp
public record PermissionRequirement(string PermissionName) : IAuthorizationRequirement;
```

### New: `PermissionAuthorizationHandler`

Location: `Auth.Infrastructure/Authorization/PermissionAuthorizationHandler.cs`

- Reads `Claim("permission", ...)` from the principal — **no DB call**
- Calls `context.Succeed(requirement)` if the claim is present
- No dependency on `IUnitOfWork` or any infrastructure service

```csharp
protected override Task HandleRequirementAsync(
    AuthorizationHandlerContext context, PermissionRequirement requirement)
{
    if (context.User.HasClaim("permission", requirement.PermissionName))
        context.Succeed(requirement);
    return Task.CompletedTask;
}
```

### New: `PermissionAuthorizationPolicyProvider`

Location: `Auth.Infrastructure/Authorization/PermissionAuthorizationPolicyProvider.cs`

- Extends `DefaultAuthorizationPolicyProvider`
- On-demand: if the requested policy name looks like a permission (e.g. `"User.Read"`), wraps it in an `AuthorizationPolicy` containing a `PermissionRequirement`
- Falls back to `base.GetPolicyAsync()` for built-in policies

### New: `RouteHandlerBuilderExtensions.RequirePermission()`

Location: `Auth.Presentation/Extensions/RouteHandlerBuilderExtensions.cs`

```csharp
public static RouteHandlerBuilder RequirePermission(
    this RouteHandlerBuilder builder, string permissionName)
    => builder.RequireAuthorization(permissionName);
```

### ApiHost registration

`Program.cs` (or `AuthenticationConfiguration.cs`):

```csharp
services.AddSingleton<IAuthorizationPolicyProvider, PermissionAuthorizationPolicyProvider>();
services.AddScoped<IAuthorizationHandler, PermissionAuthorizationHandler>();
```

### Endpoint changes

Add `.RequirePermission("X.Y")` to each admin route in the 5 endpoint extension files per the mapping table above. The group-level `.RequireAuthorization()` remains (ensures authentication); the per-route `.RequirePermission()` adds the permission check on top.

---

## Implementation Order

1. `PermissionRequirement` — trivial record
2. `PermissionAuthorizationHandler` — claim check only, no DB
3. `PermissionAuthorizationPolicyProvider` — on-demand policy creation
4. `RouteHandlerBuilderExtensions.RequirePermission()`
5. Register handler + policy provider in `Program.cs`
6. Update 5 endpoint extension files
7. Add `403 Forbidden` to `Produces` declarations where missing
8. Add/update integration tests for permission enforcement

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
| `PermissionEndpointExtensions.cs` | Add `RequirePermission` per route |
| `RoleEndpointExtensions.cs` | Add `RequirePermission` per route |
| `RoleGroupEndpointExtensions.cs` | Add `RequirePermission` per route |
| `IdpEndpointExtensions.cs` | Add `RequirePermission` per route |
| `UserManagementEndpointExtensions.cs` | Add `RequirePermission` per route |

## Files Unchanged

| File | Reason |
|------|--------|
| `UserPermissionClaimsTransformation.cs` | Already loads permissions into claims; also drives SSO auto-provisioning — must not be modified |
| `AuthenticationConfiguration.cs` | Already registers `IClaimsTransformation` correctly |
| All public/own-data endpoint extensions | No permission policy needed |

---

## Non-Goals

- Embedding permissions in JWT tokens (would require Cognito Lambda trigger)
- Adding a DB call in the authorization handler (claims transformation already covers this)
- UI changes (frontend already shows/hides based on user roles, enforcement is backend-only)
