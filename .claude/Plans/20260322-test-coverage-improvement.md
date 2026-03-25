# Plan: Unit Test and Integration Test Coverage Improvement

**Branch:** `feature/permission-enforcement`
**Date:** 2026-03-22
**Status:** Implemented
**Updated:** 2026-03-22 — added Phase 8 Frontend Tests

---

## Current State

### Backend: 22.9% line | 22.2% branch | 32.1% method (268 tests)

| Assembly | Line % | State |
|----------|--------|-------|
| `IFX.Modules.Auth.Domain` | 59.4% | Good |
| `IFX.ApiHost` | 49.1% | Acceptable — new permission classes at 80–100% |
| `IFX.Modules.Auth.Presentation` | 34.9% | Partial |
| `IFX.Modules.Auth.Composition` | 29.5% | Low |
| `IFX.Modules.Auth.Application` | 15.4% | **Critical gap** |
| `IFX.Modules.Auth.Infrastructure` | 11.3% | **Critical gap** |

### Frontend: 0% (no test tooling installed)

No test runner, no testing library, no existing test files.

---

## Backend Critical Gaps

**Application handlers — ALL at 0%:**
- 13 Authorization command handlers (CreateRole, DeleteRole, AssignPermissions, …)
- 4 Authorization query handlers (GetAllRoles, GetAllPermissions, GetRoleById, GetAllRoleGroups)
- 4 Users command handlers (AssignRolesToUser, RemoveRoleFromUser, AssignRoleGroupsToUser, RemoveRoleGroupFromUser)
- 4 Users query handlers (GetUserProfile, GetUserById, GetAllUsers, GetUserLoginHistory)
- Most Identity handlers and validators

**Infrastructure repositories — low coverage:**
- `RoleRepository`: 71.4% ✓
- `PermissionRepository`: 36.3% — partial
- `RoleGroupRepository`: 23.5% — low
- `UserRepository`: 0% — missing entirely

**Integration tests — missing permission enforcement:**
- Current: only test unauthenticated → 401
- Missing: authenticated without permission → 403
- Missing: authenticated with correct permission → 200

**ApiHost authorization — new classes partially covered:**
- `PermissionRequirement`: 100% ✓
- `PermissionAuthorizationPolicyProvider`: 90%
- `PermissionAuthorizationHandler`: 80% — missing fail path

---

## What NOT to Test

- `IFX.Platform.Shared`: infrastructure glue only — skip
- `CognitoOidcService`, `Auth0OidcService`: require live AWS/Auth0 — skip
- `OidcDiscoveryService`: requires HTTP — skip
- Endpoint handlers (static classes) — covered via integration tests

---

## Backend Implementation Plan

### Phase 1 — Integration Test Infrastructure (prerequisite)

Add `CreateAuthenticatedClient(params string[] permissions)` to `CustomWebApplicationFactory`:
- Registers a fake `"Test"` authentication scheme
- Reads claims from request header `X-Test-Claims`
- Bypasses real JWT bearer + `UserPermissionClaimsTransformation`

### Phase 2 — Integration Tests: Permission Enforcement

**New file:** `tests/IFX.IntegrationTests/Endpoints/PermissionEnforcementTests.cs`

Test matrix per permission group:

| Scenario | Expected |
|----------|----------|
| No token | 401 Unauthorized |
| Token + no permissions | 403 Forbidden |
| Token + wrong permission | 403 Forbidden |
| Token + correct permission | 200 OK / 404 (no data) |

Representative endpoint per group: `GET /api/v1/usermanagement/users`, `GET /api/v1/role`, `GET /api/v1/rolegroup`, `GET /api/v1/permission`, `GET /api/v1/idp`.

### Phase 3 — Unit Tests: ApiHost Authorization

- `PermissionAuthorizationHandler`: has permission claim → Succeed; missing → does not Succeed; empty principal → does not Succeed
- `PermissionAuthorizationPolicyProvider`: unknown name → returns policy with `PermissionRequirement`; known built-in → falls back

### Phase 4 — Unit Tests: Application — Authorization Handlers

All 13 command + 4 query handlers in `Authorization/`. Key scenarios per handler: success path, not-found failure, duplicate failure (where applicable).

### Phase 5 — Unit Tests: Application — Users Handlers

All 4 command + 4 query handlers in `Users/`. Key scenarios: success, user not found, role/group not found.

### Phase 6 — Unit Tests: Application — Validators

`CreateRoleCommandValidator`, `CreatePermissionCommandValidator`, `CreateRoleGroupCommandValidator`, `UpdateRoleCommandValidator`, `UpdatePermissionCommandValidator`.

### Phase 7 — Infrastructure Repository Tests

- New: `PermissionRepositoryTests`, `RoleGroupRepositoryTests`
- Extend: `RoleRepositoryTests` (GetAll, GetByName not found)

---

## Phase 8 — Frontend Tests

### 8.1 Test Stack Setup

**New packages to install:**

```bash
npm install -D vitest @vitest/coverage-v8 jsdom \
  @testing-library/react @testing-library/user-event @testing-library/jest-dom \
  msw
```

| Package | Purpose |
|---------|---------|
| `vitest` | Vite-native test runner (shares vite.config.ts) |
| `@vitest/coverage-v8` | Coverage via V8 |
| `jsdom` | Browser DOM environment |
| `@testing-library/react` | Component rendering + queries |
| `@testing-library/user-event` | Realistic user interactions |
| `@testing-library/jest-dom` | DOM matchers (`.toBeInTheDocument()`, etc.) |
| `msw` | Mock Service Worker — intercepts axios requests |

**New config files:**
- `vite.config.ts`: add `test: { environment: 'jsdom', setupFiles: './src/test/setup.ts', coverage: { provider: 'v8' } }`
- `src/test/setup.ts`: import `@testing-library/jest-dom`
- `src/test/server.ts`: MSW server setup with API handlers

**New `package.json` scripts:**
```json
"test": "vitest",
"test:run": "vitest run",
"test:coverage": "vitest run --coverage"
```

### 8.2 Unit Tests: Shared Components

**`src/components/shared/__tests__/Chip.test.tsx`**
- Renders label text
- Shows remove button when `onRemove` provided
- Hides remove button when `onRemove` omitted
- Calls `onRemove` when × clicked

**`src/components/shared/__tests__/Modal.test.tsx`**
- Renders title, body, footer
- Calls `onClose` when × button clicked
- Calls `onClose` when Escape key pressed
- Does not call `onClose` when other keys pressed
- Renders without footer when omitted

**`src/components/shared/__tests__/SortableHeader.test.tsx`**
- Renders label text
- Shows `↕` when column is not the active sort column
- Shows `↑` when active column and direction is `asc`
- Shows `↓` when active column and direction is `desc`
- Adds `sort-active` class to icon when active
- Calls `onSort` with correct column name on click

**`src/components/shared/__tests__/ProtectedRoute.test.tsx`**
- Shows spinner while `isLoading` is true
- Redirects to `/login` when not authenticated
- Renders children when authenticated

### 8.3 Unit Tests: API Client

**`src/api/__tests__/client.test.ts`**

`tokenStorage`:
- `save()` writes all 4 keys to localStorage
- `getAccessToken()` returns stored token
- `getRefreshToken()` returns stored token
- `clear()` removes all 4 keys

`apiClient` interceptors (using MSW):
- Request interceptor attaches `Authorization: Bearer <token>` when token present
- Request interceptor skips Authorization when no token stored
- Response interceptor: on 401, calls `/api/v1/auth/refresh`, retries original request with new token
- Response interceptor: on 401 with refresh failure, clears storage and redirects to `/login`
- Response interceptor: on 401 with no refresh token, clears storage and redirects to `/login`
- Response interceptor: on non-401 error, rejects without refresh attempt

### 8.4 Unit Tests: AuthContext

**`src/contexts/__tests__/AuthContext.test.tsx`**
- `login()` saves tokens to localStorage and loads user profile
- `logout()` clears localStorage and sets user to null
- `isAuthenticated` is `false` before login, `true` after login, `false` after logout
- On mount: restores session if token in localStorage (calls `getProfile`, sets user)
- On mount: `isLoading` is true initially, false after profile load
- On mount: no token in localStorage → `isLoading` false, `isAuthenticated` false
- `refreshUser()` re-fetches profile from API

### 8.5 Unit Tests: Auth Pages

**`src/pages/auth/__tests__/CallbackPage.test.tsx`**
- Parses `access_token` from URL hash and calls `login()`
- Redirects to `/profile` on successful login
- Shows error message when `error` param in hash
- Shows "No access token" error when hash has no `access_token`
- Shows spinner while processing (no error, no redirect yet)
- Calls `login()` with correct `expiresIn` (defaults to 3600 if missing)

**`src/pages/auth/__tests__/LoginPage.test.tsx`**
- Renders "Sign in" button
- Calls `getAuthorizeUrl()` API when button clicked
- Redirects `window.location.href` to returned authorization URL

### 8.6 Unit Tests: Management Pages (Sort Behavior)

These pages share the sort pattern — test one representative page per concern.

**`src/pages/__tests__/RoleManagementPage.test.tsx`**
- Renders role list from API response
- Clicking Name header sorts ascending
- Clicking Name header again sorts descending
- Clicking different header resets direction to ascending
- Shows spinner while loading
- Shows error alert on API failure

**`src/pages/__tests__/PermissionManagementPage.test.tsx`**
- Renders permission list
- Sort by Name ascending/descending
- Sort by Description
- "Create Permission" button opens modal
- Save in create modal calls `permissionApi.create()`
- Delete confirmation calls `permissionApi.delete()`

### 8.7 MSW Handler Setup

**`src/test/handlers.ts`** — Default API mock handlers:
```ts
// GET /api/v1/user/profile → mock UserProfileDto
// GET /api/v1/role → mock RoleDto[]
// GET /api/v1/permission → mock PermissionDto[]
// POST /api/v1/auth/refresh → mock token response
// POST /api/v1/auth/refresh (error variant) → 401
```

---

## Files to Create

### Backend (Phases 1–7)

| File | Phase |
|------|-------|
| `IFX.IntegrationTests/Fixtures/AuthenticatedClientHelper.cs` | 1 |
| `IFX.IntegrationTests/Endpoints/PermissionEnforcementTests.cs` | 2 |
| `Presentation.Tests/Authorization/PermissionAuthorizationHandlerTests.cs` | 3 |
| `Presentation.Tests/Authorization/PermissionAuthorizationPolicyProviderTests.cs` | 3 |
| `Application.Tests/Handlers/Authorization/CreateRoleCommandHandlerTests.cs` | 4 |
| `Application.Tests/Handlers/Authorization/UpdateRoleCommandHandlerTests.cs` | 4 |
| `Application.Tests/Handlers/Authorization/DeleteRoleCommandHandlerTests.cs` | 4 |
| `Application.Tests/Handlers/Authorization/GetAllRolesQueryHandlerTests.cs` | 4 |
| `Application.Tests/Handlers/Authorization/GetRoleByIdQueryHandlerTests.cs` | 4 |
| `Application.Tests/Handlers/Authorization/AssignPermissionsToRoleCommandHandlerTests.cs` | 4 |
| `Application.Tests/Handlers/Authorization/RemovePermissionFromRoleCommandHandlerTests.cs` | 4 |
| `Application.Tests/Handlers/Authorization/CreatePermissionCommandHandlerTests.cs` | 4 |
| `Application.Tests/Handlers/Authorization/DeletePermissionCommandHandlerTests.cs` | 4 |
| `Application.Tests/Handlers/Authorization/GetAllPermissionsQueryHandlerTests.cs` | 4 |
| `Application.Tests/Handlers/Authorization/CreateRoleGroupCommandHandlerTests.cs` | 4 |
| `Application.Tests/Handlers/Authorization/DeleteRoleGroupCommandHandlerTests.cs` | 4 |
| `Application.Tests/Handlers/Authorization/AssignRolesToRoleGroupCommandHandlerTests.cs` | 4 |
| `Application.Tests/Handlers/Users/GetUserProfileQueryHandlerTests.cs` | 5 |
| `Application.Tests/Handlers/Users/GetUserByIdQueryHandlerTests.cs` | 5 |
| `Application.Tests/Handlers/Users/GetAllUsersQueryHandlerTests.cs` | 5 |
| `Application.Tests/Handlers/Users/AssignRolesToUserCommandHandlerTests.cs` | 5 |
| `Application.Tests/Handlers/Users/RemoveRoleFromUserCommandHandlerTests.cs` | 5 |
| `Application.Tests/Handlers/Users/AssignRoleGroupsToUserCommandHandlerTests.cs` | 5 |
| `Application.Tests/Handlers/Users/RemoveRoleGroupFromUserCommandHandlerTests.cs` | 5 |
| `Application.Tests/Validators/Authorization/CreateRoleCommandValidatorTests.cs` | 6 |
| `Application.Tests/Validators/Authorization/CreatePermissionCommandValidatorTests.cs` | 6 |
| `Application.Tests/Validators/Authorization/CreateRoleGroupCommandValidatorTests.cs` | 6 |
| `Infrastructure.Tests/Repositories/PermissionRepositoryTests.cs` | 7 |
| `Infrastructure.Tests/Repositories/RoleGroupRepositoryTests.cs` | 7 |

### Frontend (Phase 8)

| File | Phase |
|------|-------|
| `vite.config.ts` (modify) | 8.1 |
| `src/test/setup.ts` | 8.1 |
| `src/test/server.ts` | 8.1 |
| `src/test/handlers.ts` | 8.7 |
| `src/components/shared/__tests__/Chip.test.tsx` | 8.2 |
| `src/components/shared/__tests__/Modal.test.tsx` | 8.2 |
| `src/components/shared/__tests__/SortableHeader.test.tsx` | 8.2 |
| `src/components/shared/__tests__/ProtectedRoute.test.tsx` | 8.2 |
| `src/api/__tests__/client.test.ts` | 8.3 |
| `src/contexts/__tests__/AuthContext.test.tsx` | 8.4 |
| `src/pages/auth/__tests__/CallbackPage.test.tsx` | 8.5 |
| `src/pages/auth/__tests__/LoginPage.test.tsx` | 8.5 |
| `src/pages/__tests__/RoleManagementPage.test.tsx` | 8.6 |
| `src/pages/__tests__/PermissionManagementPage.test.tsx` | 8.6 |

## Files to Modify

| File | Change |
|------|--------|
| `CustomWebApplicationFactory.cs` | Add test auth scheme + `CreateAuthenticatedClient()` |
| `AdminEndpointTests.cs` | Add authenticated + permission scenarios |
| `RoleRepositoryTests.cs` | Add GetAll, GetByName-missing scenarios |
| `src/Frontend/.../vite.config.ts` | Add `test` block |
| `src/Frontend/.../package.json` | Add test scripts + devDependencies |

---

## Expected Outcome

### Backend

| Assembly | Current | Target |
|----------|---------|--------|
| `IFX.Modules.Auth.Application` | 15.4% | ~55% |
| `IFX.Modules.Auth.Infrastructure` | 11.3% | ~40% |
| `IFX.ApiHost` | 49.1% | ~65% |
| **Overall** | **22.9%** | **~40%** |

Backend tests: 268 → ~370

### Frontend

| Area | Current | Target |
|------|---------|--------|
| Shared components | 0% | ~90% |
| API client / tokenStorage | 0% | ~85% |
| AuthContext | 0% | ~85% |
| Auth pages | 0% | ~80% |
| Management pages (sort) | 0% | ~60% |
| **Frontend overall** | **0%** | **~75%** |

Frontend tests: 0 → ~60
