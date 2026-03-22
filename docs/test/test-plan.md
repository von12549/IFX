# Test Plan

## 1. Purpose

This document describes what is being tested in IFX, the approach taken for each layer, and the phased delivery of the test suite. It bridges the high-level Test Strategy and the detailed Test Cases.

---

## 2. System Under Test

**IFX** — ASP.NET Core 8 authentication platform with:

- OAuth 2.0 / PKCE Authorization Code flow (Cognito, Auth0 adapters)
- Dynamic Multi-IdP SSO with auto-provisioning
- Role-based authorization with fine-grained Permissions
- CQRS via MediatR (Commands + Queries)
- Clean Architecture (Domain → Application → Infrastructure → Presentation)
- React frontend (Vite + TypeScript)
- Platform services: Hangfire (background jobs), SendGrid (email)

---

## 3. Test Layers

### 3.1 Domain Layer (`IFX.Modules.Auth.Domain.Tests`) — 103 tests

**What**: Business entities, value objects, and their invariants.

**How**: Pure xUnit unit tests. No mocks, no EF Core, no DI. Test factory methods, state transitions, and validation rules encoded in the domain.

**Entities covered**:
- `User` — creation, activation/deactivation, display name update, role assignment
- `UserIdentity` — creation with value objects (Subject, EmailAddress)
- `LoginEvent` — creation, device info parsing
- `EmailVerificationToken` — creation, expiry, usage state
- `Role` — creation, permission assignment

**Value objects covered**:
- `EmailAddress` — normalization to lowercase, null/empty rejection
- `Subject` — raw value storage, equality
- `DeviceInfo` — user-agent parsing into OS, browser, device type, bot detection

---

### 3.2 Application Layer (`IFX.Modules.Auth.Application.Tests`) — 190 tests

**What**: CQRS handlers, FluentValidation validators, MediatR pipeline behaviors, and the Result pattern.

**How**: xUnit with Moq. All dependencies (`IUnitOfWork`, `IMapper`, `ILogger`, `IMediator`) are mocked. Tests assert on return values, mock invocations, and error messages. No EF Core or database involved.

#### 3.2.1 Authorization Handlers (15 handlers)

| Handler | Test Focus |
|---------|-----------|
| `CreateRoleCommandHandler` | Success path; duplicate name returns failure |
| `UpdateRoleCommandHandler` | Success; not found; duplicate name; short name |
| `DeleteRoleCommandHandler` | Success; not found |
| `GetAllRolesQueryHandler` | Returns mapped DTOs |
| `GetRoleByIdQueryHandler` | Found returns DTO; not found returns failure |
| `AssignPermissionsToRoleCommandHandler` | Success; role not found; some permissions missing |
| `RemovePermissionFromRoleCommandHandler` | Success; role not found; permission not assigned |
| `CreatePermissionCommandHandler` | Success; duplicate name returns failure |
| `DeletePermissionCommandHandler` | Success; not found |
| `GetAllPermissionsQueryHandler` | Returns mapped list |
| `CreateRoleGroupCommandHandler` | Success; duplicate name returns failure |
| `DeleteRoleGroupCommandHandler` | Success; not found |
| `AssignRolesToRoleGroupCommandHandler` | Success; group not found; partial role resolution |
| `GetAllRoleGroupsQueryHandler` | Returns mapped list |
| `UpdateRoleCommandHandler` | Full update path with validation |

#### 3.2.2 User Handlers (7 handlers)

| Handler | Test Focus |
|---------|-----------|
| `GetUserProfileQueryHandler` | Found returns profile DTO; not found returns failure |
| `GetUserByIdQueryHandler` | Found; not found |
| `GetAllUsersQueryHandler` | Paginated result; empty list |
| `AssignRolesToUserCommandHandler` | Success; user not found; role not found |
| `RemoveRoleFromUserCommandHandler` | Success; user not found |
| `AssignRoleGroupsToUserCommandHandler` | Success; user not found; group not found |
| `RemoveRoleGroupFromUserCommandHandler` | Success; user not found |

#### 3.2.3 Identity Handlers (3 handlers)

| Handler | Test Focus |
|---------|-----------|
| `SendEmailVerificationCommandHandler` | Token creation and email dispatch |
| `ResendEmailVerificationCommandHandler` | Existing token replacement |
| `VerifyEmailCommandHandler` | Valid token; expired token; already verified |

#### 3.2.4 Validators (8 validators)

| Validator | Test Focus |
|-----------|-----------|
| `RegisterUserCommandValidator` | Email format; password length; required fields |
| `LoginUserCommandValidator` | Required email; required password |
| `CreateRoleCommandValidator` | Name required, max 50; description required, max 255 |
| `UpdateRoleCommandValidator` | RoleId not empty; name min 3, max 50; description required |
| `CreatePermissionCommandValidator` | Name required, max 100; description required, max 255 |
| `UpdatePermissionCommandValidator` | PermissionId not empty; name max 100; description max 255 |
| `CreateRoleGroupCommandValidator` | Name required, max 100; description required, max 255 |
| `UpdateRoleGroupCommandValidator` | RoleGroupId not empty; name max 100; description max 255 |

#### 3.2.5 Behaviors and Common

| Class | Test Focus |
|-------|-----------|
| `ValidationBehavior<TRequest, TResponse>` | Passes through when valid; aggregates and returns validation failures |
| `Result<T>` | Success/failure construction; value access; error access |

---

### 3.3 Infrastructure Layer (`IFX.Modules.Auth.Infrastructure.Tests`) — 45 tests

**What**: Repository implementations against EF Core InMemory.

**How**: Each test class creates a fresh `IfxDbContext` with a unique in-memory database name (`Guid.NewGuid()`), seeds data directly via the context, and exercises the repository. Database is deleted on `Dispose()`.

#### Repositories Covered

| Repository | Operations Tested |
|------------|-------------------|
| `RoleRepository` | `GetByIdAsync`, `GetByNameAsync`, `NameExistsAsync`, `NameExistsAsync` with exclude ID, `GetAllAsync`, `AddAsync` |
| `PermissionRepository` | `GetByIdAsync`, `GetAllAsync`, `GetByIdsAsync`, `NameExistsAsync`, `AddAsync`, `UpdateAsync`, `DeleteAsync` |
| `RoleGroupRepository` | `GetByIdAsync`, `GetAllAsync`, `NameExistsAsync`, `AddAsync`, `UpdateAsync`, `DeleteAsync`, `GetByIdWithRolesAsync` |

#### Services Covered

| Service | Operations Tested |
|---------|------------------|
| `EmailVerificationService` | Token generation; expiry calculation; used/unused state transitions |

---

### 3.4 Presentation Layer (`IFX.Modules.Auth.Presentation.Tests`) — 10 tests

**What**: Extension methods used by minimal API endpoints to read claims and HTTP context.

| Class | Test Focus |
|-------|-----------|
| `ClaimsPrincipalExtensions` | `GetUserId()`, `GetPermissions()`, `HasPermission()` — present/absent claims |
| `HttpContextExtensions` | `GetIdpConfiguration()`, `GetAccessToken()` — Items dictionary access |

---

### 3.5 Integration Tests (`IFX.IntegrationTests`) — 43 tests

**What**: Full HTTP request pipeline from `HttpClient` through the ASP.NET Core middleware stack, authorization layer, endpoint handlers, and EF Core InMemory database.

**How**: `CustomWebApplicationFactory` (extends `WebApplicationFactory<Program>`) replaces the real JWT `DynamicJwtBearerMiddleware` with `TestAuthHandler`, which reads `X-Test-Permissions` header to inject permission claims — no JWT required.

```csharp
// Creates client with no auth header → triggers 401
factory.CreateClient()

// Creates client with bearer token but no permissions → triggers 403
factory.CreateAuthenticatedClient()

// Creates client with bearer token + "User.Read" permission claim → allows through
factory.CreateAuthenticatedClient("User.Read")
```

#### Test Groups

| Group | Tests | Coverage |
|-------|-------|---------|
| `PermissionEnforcementTests` | 18 | 401/403/200 matrix for Users, Roles, RoleGroups, Permissions, Idps endpoints |
| `PermissionAuthorizationHandlerTests` | 13 | Handler permit/deny logic; multiple permissions; missing requirement |
| `PermissionAuthorizationPolicyProviderTests` | 12 | Policy creation; caching; fallback to default policy |
| `AdminEndpointTests` | — | Admin-only endpoints smoke tests |
| `AuthEndpointTests` | — | Register, confirm, OAuth callback |
| `HealthEndpointTests` | — | `GET /health`, `GET /health/ready` |
| `UserEndpointTests` | — | Profile get/update |

---

### 3.6 Platform Tests

#### BackgroundJobs (`IFX.Platform.BackgroundJobs.Tests`) — 11 tests

**What**: `HangfireBackgroundJobService` — the concrete implementation of `IBackgroundJobService`.

**How**: Moq mocks of `IBackgroundJobClient` and `IRecurringJobManager`. Verifies correct Hangfire client method calls.

| Method | Tests |
|--------|-------|
| `Enqueue<T>` | Fire-and-forget job queued |
| `Schedule<T>` | Delayed job scheduled with correct delay |
| `AddOrUpdateRecurring<T>` | Recurring job registered with cron expression |
| `RemoveRecurring` | Recurring job removed by ID |

#### Notifications (`IFX.Platform.Notifications.Tests`) — 17 tests

**What**: `SendGridEmailService` and `NoOpEmailService`.

| Method | Tests |
|--------|-------|
| `SendEmailAsync` | To/Subject/HtmlBody sent; default from address; custom from address |
| `SendTemplatedEmailAsync` | Template ID and dynamic data forwarded; CC/BCC included |
| `SendBatchAsync` | Multiple recipients dispatched |
| `NoOpEmailService` | All methods complete without throwing; no real dispatch |

---

### 3.7 Frontend Tests (`IFX.FrontEnd`) — 55 tests

**What**: React components, custom hooks, API client, and page-level interactions.

**How**: Vitest + React Testing Library + MSW. All HTTP calls are intercepted by MSW node server before they reach the network. Default handlers serve realistic mock data; individual tests override specific handlers with `server.use(...)`.

#### Shared Components

| Component | Tests |
|-----------|-------|
| `Chip` | Renders label; applies `chip-active` class; click callback; no callback when inactive |
| `Modal` | Renders when `isOpen=true`; hides when `isOpen=false`; Escape key closes; × button closes; renders children |
| `SortableHeader` | Default renders without active indicator; click sets sort; second click toggles direction; `sort-active` class on icon span |
| `ProtectedRoute` | Renders children when authenticated; redirects to login when unauthenticated; shows loading state |

#### API Client

| Module | Tests |
|--------|-------|
| `tokenStorage` | Save and retrieve tokens; clear removes all; expired tokens return null; missing tokens return null |

#### AuthContext

| Scenario | Tests |
|----------|-------|
| Mount | Restores session from `tokenStorage` if valid |
| `login()` | Calls `POST /api/v1/auth/refresh`; stores tokens; fetches profile |
| `logout()` | Clears token storage; resets user state |
| Unauthenticated | No stored token → `user` is null |
| Profile fetch failure | Server error → user stays null |

#### Auth Pages

| Page | Tests |
|------|-------|
| `LoginPage` | Renders login button; clicking redirects to OAuth authorize URL; handles missing authorize URL; handles API error |
| `CallbackPage` | Parses `access_token` from URL hash; calls `login()`; navigates to `/`; handles missing token; handles login error; shows loading state |

#### Management Pages

| Page | Tests |
|------|-------|
| `RoleManagementPage` | Renders role list; sort by name ascending; sort by name descending; opens create modal; create role calls POST; delete opens confirmation; confirmed delete calls DELETE |
| `PermissionManagementPage` | Renders permission list; sort ascending; sort descending; opens create modal; create calls POST; delete opens confirmation; confirmed delete calls DELETE; cancel delete dismisses modal |

---

## 4. Phased Delivery

The test suite was built in 8 phases aligned with feature development:

| Phase | Scope | Tests Added |
|-------|-------|------------|
| 1 | Integration test infrastructure (`TestAuthHandler`, `CustomWebApplicationFactory`) | — |
| 2 | Permission enforcement integration tests (401/403/200 matrix) | 18 |
| 3 | `PermissionAuthorizationHandler` + `PermissionAuthorizationPolicyProvider` unit tests | 25 |
| 4 | Authorization application handler tests (14 handlers) | ~70 |
| 5 | User application handler tests (7 handlers) | ~35 |
| 6 | Validator tests — Create + Update for Role, Permission, RoleGroup | ~45 |
| 7 | Repository tests — Permission, RoleGroup, Role | 45 |
| 8 | Frontend test infrastructure + all 10 component/page test files | 55 |

---

## 5. Test Execution

### Run All Tests

```bash
# Backend (419 tests)
dotnet test IFX.sln

# Frontend (55 tests)
cd src/Frontend/IFX.FrontEnd
npm run test:run
```

### Selective Runs

```bash
# Unit tests only (exclude integration)
dotnet test IFX.sln --filter "FullyQualifiedName!~IntegrationTests"

# Single test project
dotnet test tests/IFX.Modules.Auth.Application.Tests

# Single test by name pattern
dotnet test IFX.sln --filter "DisplayName~CreateRole"

# With coverage
dotnet test IFX.sln --collect:"XPlat Code Coverage" --results-directory ./coverage-results
reportgenerator -reports:"coverage-results/**/coverage.cobertura.xml" \
  -targetdir:"coverage-report" -reporttypes:"Html;TextSummary" \
  -assemblyfilters:"+IFX.*;-*Tests*"

# Frontend watch mode
cd src/Frontend/IFX.FrontEnd
npm run test

# Frontend with coverage
npm run test:coverage
```

---

## 6. Known Gaps and Risks

| Gap | Risk | Mitigation |
|-----|------|-----------|
| `GetOrProvisionUserQueryHandler` not unit tested | SSO provisioning regressions | Covered indirectly by integration tests; direct handler test planned |
| No E2E tests for OAuth callback flow | Real Cognito redirect broken undetected | Manual smoke test on staging before each release |
| `Auth.Infrastructure` coverage at 12.2% | Repository bugs not caught | Expanding repository tests in future phase |
| No load tests for concurrent SSO provisioning | Race condition may reappear under load | Race condition fixed at application layer; DB unique constraint as safety net |
| Frontend covers happy path for CRUD but not all error states | Error handling regressions | MSW handler overrides available; extend tests per feature |
