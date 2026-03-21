# Plan: Unit Test and Integration Test Coverage Improvement

**Branch:** `feature/permission-enforcement`
**Date:** 2026-03-22

---

## Current State

**Overall: 22.9% line | 22.2% branch | 32.1% method** across 268 passing tests.

### Coverage by Assembly

| Assembly | Line % | State |
|----------|--------|-------|
| `IFX.Modules.Auth.Domain` | 59.4% | Good — domain entities well covered |
| `IFX.ApiHost` | 49.1% | Acceptable — new permission classes at 80–100% |
| `IFX.Modules.Auth.Presentation` | 34.9% | Partial |
| `IFX.Modules.Auth.Composition` | 29.5% | Low |
| `IFX.Modules.Auth.Application` | 15.4% | **Critical gap** |
| `IFX.Modules.Auth.Infrastructure` | 11.3% | **Critical gap** |

### Critical Gaps

**Application handlers — ALL at 0%:**
- 13 Authorization command handlers (CreateRole, DeleteRole, AssignPermissions, …)
- 4 Authorization query handlers (GetAllRoles, GetAllPermissions, GetRoleById, GetAllRoleGroups)
- 4 Users command handlers (AssignRolesToUser, RemoveRoleFromUser, AssignRoleGroupsToUser, RemoveRoleGroupFromUser)
- 4 Users query handlers (GetUserProfile, GetUserById, GetAllUsers, GetAllUsers)
- 8 Identity command handlers (RegisterUser, ConfirmRegistration, LoginUser, LogoutUser, RefreshToken, RevokeToken, CreateIdp, UpdateIdp, SyncUser, ProvisionSsoUser)
- 4 Identity query handlers (GetAllIdps, GetIdpById, GetOrProvisionUser)

**Validators — mostly 0%:**
- Covered: `LoginUserCommandValidator` (100%), `RegisterUserCommandValidator` (100%), `RevokeTokenCommandValidator` (100%)
- Not covered: All Authorization/Users/Identity validators

**Infrastructure repositories — low coverage:**
- `RoleRepository`: 71.4% ✓
- `PermissionRepository`: 36.3% — partial
- `RoleGroupRepository`: 23.5% — low
- `IdpRepository`: 16.3% — low
- `UserRepository`: 0% — missing
- `UserIdentityRepository`: 10.5% — low
- `EmailVerificationTokenRepository`: 7.8% — low

**Integration tests — missing permission enforcement:**
- Current: only test unauthenticated → 401
- Missing: authenticated without required permission → 403
- Missing: authenticated with correct permission → 200

**ApiHost authorization — new classes partially covered:**
- `PermissionRequirement`: 100% ✓
- `PermissionAuthorizationPolicyProvider`: 90% — missing fallback path
- `PermissionAuthorizationHandler`: 80% — missing fail path

---

## What NOT to Test

- `IFX.Platform.Shared`: 0% but contains only infrastructure glue — skip
- `CognitoOidcService`, `Auth0OidcService`: require live AWS/Auth0 — skip (integration concern)
- `OidcDiscoveryService`: requires HTTP — skip (already covered by infrastructure mocks)
- Endpoint handlers themselves (static classes) — covered via integration tests, not unit tests

---

## Implementation Plan

### Phase 1 — Integration Test Infrastructure (prerequisite for permission tests)

**Problem:** Integration tests currently have no way to make authenticated requests. All permission-enforcement tests need a user with specific permission claims.

**Solution:** Add a `TestAuthenticationScheme` to `CustomWebApplicationFactory` that accepts a special test token format and creates a `ClaimsPrincipal` with caller-specified claims, bypassing JWT validation and `UserPermissionClaimsTransformation`.

**Changes:**
- `CustomWebApplicationFactory`: add `CreateAuthenticatedClient(params string[] permissions)` helper
  - Registers a fake `"Test"` authentication scheme
  - Reads claims from a request header `X-Test-Claims` (JSON)
  - Bypasses the real JWT bearer + claims transformation
- Add `AuthenticatedWebApplicationFactory` subclass or factory method

### Phase 2 — Integration Tests: Permission Enforcement

**New file:** `tests/IFX.IntegrationTests/Endpoints/PermissionEnforcementTests.cs`

Test matrix for every admin endpoint group:

| Scenario | Expected |
|----------|----------|
| No token | 401 Unauthorized |
| Token + no permissions | 403 Forbidden |
| Token + wrong permission (e.g. `User.Read` on a `Role.*` endpoint) | 403 Forbidden |
| Token + correct permission | 200 OK (or 404 for missing resource) |

Endpoints to cover:
- `GET /api/v1/usermanagement/users` — `User.Read`
- `GET /api/v1/role` — `Role.Read`
- `POST /api/v1/role` — `Role.Write`
- `GET /api/v1/rolegroup` — `RoleGroup.Read`
- `POST /api/v1/permission` — `Permission.Write`
- `GET /api/v1/idp` — `Idp.Read`

(One representative endpoint per permission group is sufficient — the policy provider and handler are shared.)

### Phase 3 — Unit Tests: ApiHost Authorization

**New file:** `tests/IFX.Modules.Auth.Presentation.Tests/Authorization/PermissionAuthorizationHandlerTests.cs`

- `HandleRequirement_UserHasPermissionClaim_Succeeds`
- `HandleRequirement_UserMissingPermissionClaim_DoesNotSucceed`
- `HandleRequirement_EmptyPrincipal_DoesNotSucceed`

**New file:** `tests/IFX.Modules.Auth.Presentation.Tests/Authorization/PermissionAuthorizationPolicyProviderTests.cs`

- `GetPolicyAsync_UnknownPolicyName_ReturnsPolicyWithPermissionRequirement`
- `GetPolicyAsync_KnownBuiltInPolicy_ReturnsFallbackPolicy`

> Note: Place in Presentation.Tests project since it already references the right test infrastructure; the tested types are in ApiHost but the test boundary is the same layer.

### Phase 4 — Unit Tests: Application — Authorization Handlers

**New file:** `tests/IFX.Modules.Auth.Application.Tests/Handlers/Authorization/`

Priority handlers (highest business value, representative of the pattern):

| Handler | Key scenarios |
|---------|--------------|
| `CreateRoleCommandHandler` | Success; duplicate name → failure |
| `UpdateRoleCommandHandler` | Success; role not found → failure |
| `DeleteRoleCommandHandler` | Success; role not found → failure |
| `GetAllRolesQueryHandler` | Returns mapped list |
| `GetRoleByIdQueryHandler` | Found → success; not found → failure |
| `AssignPermissionsToRoleCommandHandler` | Success; role not found → failure; permission not found → failure |
| `RemovePermissionFromRoleCommandHandler` | Success; not found → failure |
| `CreatePermissionCommandHandler` | Success; duplicate → failure |
| `DeletePermissionCommandHandler` | Success; not found → failure |
| `GetAllPermissionsQueryHandler` | Returns mapped list |
| `CreateRoleGroupCommandHandler` | Success; duplicate → failure |
| `DeleteRoleGroupCommandHandler` | Success; not found → failure |
| `AssignRolesToRoleGroupCommandHandler` | Success; not found → failure |

### Phase 5 — Unit Tests: Application — Users Handlers

**New file:** `tests/IFX.Modules.Auth.Application.Tests/Handlers/Users/`

| Handler | Key scenarios |
|---------|--------------|
| `GetUserProfileQueryHandler` | Found → success; not found → failure |
| `GetUserByIdQueryHandler` | Found → success; not found → failure |
| `GetAllUsersQueryHandler` | Returns paged result |
| `AssignRolesToUserCommandHandler` | Success; user not found → failure; role not found → failure |
| `RemoveRoleFromUserCommandHandler` | Success; user not found → failure |
| `AssignRoleGroupsToUserCommandHandler` | Success; user not found → failure |
| `RemoveRoleGroupFromUserCommandHandler` | Success; user not found → failure |

### Phase 6 — Unit Tests: Application — Validators

**New file:** `tests/IFX.Modules.Auth.Application.Tests/Validators/Authorization/`

| Validator | Key scenarios |
|-----------|--------------|
| `CreateRoleCommandValidator` | Empty name → invalid; valid → passes |
| `CreatePermissionCommandValidator` | Empty name → invalid; valid → passes |
| `CreateRoleGroupCommandValidator` | Empty name → invalid; valid → passes |
| `UpdateRoleCommandValidator` | Empty name → invalid |
| `UpdatePermissionCommandValidator` | Empty name → invalid |

### Phase 7 — Infrastructure Repository Tests

**New file:** `tests/IFX.Modules.Auth.Infrastructure.Tests/Persistence/Repositories/PermissionRepositoryTests.cs`
- `GetByIdAsync_ExistingPermission_ReturnsPermission`
- `GetByIdAsync_NonExisting_ReturnsNull`
- `GetByNameAsync_ExistingPermission_ReturnsPermission`
- `GetAllAsync_ReturnsAll`

**New file:** `tests/IFX.Modules.Auth.Infrastructure.Tests/Persistence/Repositories/RoleGroupRepositoryTests.cs`
- `GetByIdAsync_ExistingRoleGroup_ReturnsWithRoles`
- `GetAllAsync_ReturnsAll`

**Extend existing:** `RoleRepositoryTests.cs`
- `GetAllAsync_ReturnsAllRoles`
- `GetByNameAsync_NonExisting_ReturnsNull`

---

## Files to Create

| File | Phase |
|------|-------|
| `IFX.IntegrationTests/Fixtures/AuthenticatedClientHelper.cs` | 1 |
| `IFX.IntegrationTests/Endpoints/PermissionEnforcementTests.cs` | 2 |
| `IFX.Modules.Auth.Presentation.Tests/Authorization/PermissionAuthorizationHandlerTests.cs` | 3 |
| `IFX.Modules.Auth.Presentation.Tests/Authorization/PermissionAuthorizationPolicyProviderTests.cs` | 3 |
| `IFX.Modules.Auth.Application.Tests/Handlers/Authorization/CreateRoleCommandHandlerTests.cs` | 4 |
| `IFX.Modules.Auth.Application.Tests/Handlers/Authorization/UpdateRoleCommandHandlerTests.cs` | 4 |
| `IFX.Modules.Auth.Application.Tests/Handlers/Authorization/DeleteRoleCommandHandlerTests.cs` | 4 |
| `IFX.Modules.Auth.Application.Tests/Handlers/Authorization/GetAllRolesQueryHandlerTests.cs` | 4 |
| `IFX.Modules.Auth.Application.Tests/Handlers/Authorization/GetRoleByIdQueryHandlerTests.cs` | 4 |
| `IFX.Modules.Auth.Application.Tests/Handlers/Authorization/AssignPermissionsToRoleCommandHandlerTests.cs` | 4 |
| `IFX.Modules.Auth.Application.Tests/Handlers/Authorization/RemovePermissionFromRoleCommandHandlerTests.cs` | 4 |
| `IFX.Modules.Auth.Application.Tests/Handlers/Authorization/CreatePermissionCommandHandlerTests.cs` | 4 |
| `IFX.Modules.Auth.Application.Tests/Handlers/Authorization/DeletePermissionCommandHandlerTests.cs` | 4 |
| `IFX.Modules.Auth.Application.Tests/Handlers/Authorization/GetAllPermissionsQueryHandlerTests.cs` | 4 |
| `IFX.Modules.Auth.Application.Tests/Handlers/Authorization/CreateRoleGroupCommandHandlerTests.cs` | 4 |
| `IFX.Modules.Auth.Application.Tests/Handlers/Authorization/DeleteRoleGroupCommandHandlerTests.cs` | 4 |
| `IFX.Modules.Auth.Application.Tests/Handlers/Authorization/AssignRolesToRoleGroupCommandHandlerTests.cs` | 4 |
| `IFX.Modules.Auth.Application.Tests/Handlers/Users/GetUserProfileQueryHandlerTests.cs` | 5 |
| `IFX.Modules.Auth.Application.Tests/Handlers/Users/GetUserByIdQueryHandlerTests.cs` | 5 |
| `IFX.Modules.Auth.Application.Tests/Handlers/Users/GetAllUsersQueryHandlerTests.cs` | 5 |
| `IFX.Modules.Auth.Application.Tests/Handlers/Users/AssignRolesToUserCommandHandlerTests.cs` | 5 |
| `IFX.Modules.Auth.Application.Tests/Handlers/Users/RemoveRoleFromUserCommandHandlerTests.cs` | 5 |
| `IFX.Modules.Auth.Application.Tests/Handlers/Users/AssignRoleGroupsToUserCommandHandlerTests.cs` | 5 |
| `IFX.Modules.Auth.Application.Tests/Handlers/Users/RemoveRoleGroupFromUserCommandHandlerTests.cs` | 5 |
| `IFX.Modules.Auth.Application.Tests/Validators/Authorization/CreateRoleCommandValidatorTests.cs` | 6 |
| `IFX.Modules.Auth.Application.Tests/Validators/Authorization/CreatePermissionCommandValidatorTests.cs` | 6 |
| `IFX.Modules.Auth.Application.Tests/Validators/Authorization/CreateRoleGroupCommandValidatorTests.cs` | 6 |
| `IFX.Modules.Auth.Infrastructure.Tests/Persistence/Repositories/PermissionRepositoryTests.cs` | 7 |
| `IFX.Modules.Auth.Infrastructure.Tests/Persistence/Repositories/RoleGroupRepositoryTests.cs` | 7 |

## Files to Modify

| File | Change |
|------|--------|
| `IFX.IntegrationTests/Fixtures/CustomWebApplicationFactory.cs` | Add test auth scheme + `CreateAuthenticatedClient()` |
| `IFX.IntegrationTests/Endpoints/AdminEndpointTests.cs` | Add authenticated + permission scenarios |
| `IFX.Modules.Auth.Infrastructure.Tests/Persistence/Repositories/RoleRepositoryTests.cs` | Add missing scenarios |

---

## Expected Outcome

| Assembly | Current | Target |
|----------|---------|--------|
| `IFX.Modules.Auth.Application` | 15.4% | ~55% |
| `IFX.Modules.Auth.Infrastructure` | 11.3% | ~40% |
| `IFX.ApiHost` | 49.1% | ~65% |
| **Overall** | **22.9%** | **~40%** |

Total tests: 268 → ~370 (adding ~100 new tests)
