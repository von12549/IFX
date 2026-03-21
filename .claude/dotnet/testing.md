# Testing

## Purpose
Testing approach, project structure, and patterns.

---

## Backend Test Projects

### Auth Module Tests (348 tests)

| Project | Purpose | Tests |
|---------|---------|-------|
| `IFX.Tests.Common` | Shared utilities, builders, fixtures | - |
| `IFX.Modules.Auth.Domain.Tests` | Entity and value object tests | 103 |
| `IFX.Modules.Auth.Application.Tests` | Handler, validator, and behavior tests | 190 |
| `IFX.Modules.Auth.Infrastructure.Tests` | Repository tests (in-memory EF) | 45 |
| `IFX.Modules.Auth.Presentation.Tests` | Authorization class unit tests | 10 |

### Platform Module Tests (28 tests)

| Project | Purpose | Tests |
|---------|---------|-------|
| `IFX.Platform.BackgroundJobs.Tests` | Hangfire service tests | 11 |
| `IFX.Platform.Notifications.Tests` | Email service tests | 17 |

### Integration Tests (43 tests)

| Project | Purpose | Tests |
|---------|---------|-------|
| `IFX.IntegrationTests` | Permission enforcement + API end-to-end | 43 |

**Total: 376 unit tests + 43 integration tests = 419 backend tests**

---

## Frontend Test Stack (55 tests)

Located in `src/Frontend/IFX.FrontEnd/src/`.

| Package | Purpose |
|---------|---------|
| `vitest` | Vite-native test runner |
| `@vitest/coverage-v8` | Coverage via V8 |
| `jsdom` | Browser DOM environment |
| `@testing-library/react` | Component rendering + queries |
| `@testing-library/user-event` | Realistic user interactions |
| `@testing-library/jest-dom` | DOM matchers |
| `msw` | Mock Service Worker — intercepts axios requests in tests |

### Frontend Test Files

| File | Tests |
|------|-------|
| `src/components/shared/__tests__/Chip.test.tsx` | 4 |
| `src/components/shared/__tests__/Modal.test.tsx` | 5 |
| `src/components/shared/__tests__/SortableHeader.test.tsx` | 7 |
| `src/components/shared/__tests__/ProtectedRoute.test.tsx` | 3 |
| `src/api/__tests__/client.test.ts` | 5 |
| `src/contexts/__tests__/AuthContext.test.tsx` | 5 |
| `src/pages/auth/__tests__/CallbackPage.test.tsx` | 6 |
| `src/pages/auth/__tests__/LoginPage.test.tsx` | 5 |
| `src/pages/__tests__/RoleManagementPage.test.tsx` | 7 |
| `src/pages/__tests__/PermissionManagementPage.test.tsx` | 8 |

### MSW Test Infrastructure

`src/test/setup.ts` — imports `@testing-library/jest-dom` and starts/resets/stops MSW server.

`src/test/server.ts` — MSW node server used in all tests.

`src/test/handlers.ts` — Default API handlers for profile, roles, permissions, auth/refresh, authorize URL. Individual tests override specific handlers via `server.use(...)`.

---

## Backend Technology Stack

- **xUnit** - Test framework
- **FluentAssertions** - Assertion library
- **Moq** - Mocking framework
- **AutoFixture** - Test data generation
- **Bogus** - Realistic fake data
- **Microsoft.AspNetCore.Mvc.Testing** - Integration testing
- **EF Core InMemory** - In-memory database for repository tests

---

## Test Naming Convention

```
{MethodName}_{Scenario}_{ExpectedBehavior}
```

Examples:
- `Create_WithValidEmail_ReturnsEmailAddress`
- `Handle_WithValidCommand_ReturnsSuccess`
- `Validate_WithEmptyName_Fails`

---

## Builders (Test Data)

Located in `Tests.Common/Builders/`:

```csharp
var user = new UserBuilder().Active().Build();
var role = new RoleBuilder().AsAdmin().Build();
```

---

## Integration Test Auth Helper

`CustomWebApplicationFactory` provides `CreateAuthenticatedClient(params string[] permissions)`:

```csharp
// Unauthenticated (401 expected)
var client = factory.CreateClient();

// Authenticated, no permissions (403 expected)
var client = factory.CreateAuthenticatedClient();

// Authenticated with specific permission (200 expected)
var client = factory.CreateAuthenticatedClient("Users.Read");
```

Uses `TestAuthHandler` — reads `X-Test-Permissions` header, bypasses JWT + `UserPermissionClaimsTransformation`.

---

## Platform Tests

### BackgroundJobs Tests

Tests `HangfireBackgroundJobService` with mocked `IBackgroundJobClient` and `IRecurringJobManager`.

### Notifications Tests

Tests `SendGridEmailService` and `NoOpEmailService`. Coverage: `SendEmailAsync`, `SendTemplatedEmailAsync`, `SendBatchAsync`, CC/BCC, default/custom from address.

---

## Run Tests

```bash
# All backend tests
dotnet test IFX.sln

# Unit tests only (excludes integration)
dotnet test IFX.sln --filter "FullyQualifiedName!~IntegrationTests"

# Specific project
dotnet test tests/IFX.Modules.Auth.Application.Tests

# With coverage + HTML report
dotnet test IFX.sln --collect:"XPlat Code Coverage" --results-directory ./coverage-results
reportgenerator -reports:"coverage-results/**/coverage.cobertura.xml" \
  -targetdir:"coverage-report" -reporttypes:"Html;TextSummary" \
  -assemblyfilters:"+IFX.*;-*Tests*"

# Frontend tests
cd src/Frontend/IFX.FrontEnd
npm run test:run        # run once
npm run test            # watch mode
npm run test:coverage   # with coverage
```
