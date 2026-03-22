# Test Strategy

## 1. Purpose

This document defines the overall testing philosophy, objectives, scope, tooling choices, and quality gates for the IFX platform. It provides the framework within which the Test Plan and Test Cases are written.

---

## 2. Testing Objectives

| Objective | Target |
|-----------|--------|
| Prevent regressions across all layers | All layers covered by automated tests |
| Enforce architectural invariants | Domain has zero external dependencies; flow verified via unit tests |
| Validate permission enforcement | Every admin endpoint covered by the 401/403/200 matrix |
| Catch concurrency and race conditions | SSO provisioning race condition covered and documented |
| Support refactoring safely | Test suite runnable in under 2 minutes locally |
| Frontend parity | All UI components, pages, and API interactions covered by component tests |

---

## 3. Test Pyramid

```
        ▲
       /|\
      / | \
     /  |  \    Integration Tests  (43 tests)
    /   |   \   • Full HTTP pipeline
   /    |    \  • Real DI container + in-memory DB
  /     |     \ • Permission enforcement matrix
 /──────┼──────\
/       |       \  Unit Tests — Infrastructure  (45 tests)
\       |       /  • Repository methods against EF Core InMemory
 \──────┼──────/
  \     |     /   Unit Tests — Application  (190 tests)
   \    |    /    • CQRS handlers via Moq'd UoW
    \   |   /    • Validators (FluentValidation)
     \  |  /     • Behaviors (pipeline)
      \ | /
       \|/   Unit Tests — Domain  (103 tests)
        ▼    • Entity factory methods
             • Value object invariants
             • Builder utilities
```

**Frontend (55 tests — separate pyramid):**

```
Component Tests (55 tests)
• Vitest + React Testing Library
• MSW intercepts all HTTP (no real network calls)
• Covers rendering, interactions, auth flows, sort/filter, CRUD modals
```

**Total: 474 tests (419 backend + 55 frontend)**

---

## 4. Scope

### In Scope

| Area | Covered By |
|------|------------|
| Domain entities and value objects | `Auth.Domain.Tests` |
| CQRS command and query handlers | `Auth.Application.Tests` |
| FluentValidation validators | `Auth.Application.Tests` |
| MediatR pipeline behaviors | `Auth.Application.Tests` |
| EF Core repositories | `Auth.Infrastructure.Tests` |
| Authorization classes (claims principal extensions) | `Auth.Presentation.Tests` |
| Permission enforcement on all admin endpoints | `IntegrationTests` |
| `PermissionAuthorizationHandler` / `PermissionAuthorizationPolicyProvider` | `IntegrationTests` |
| Background job service (Hangfire) | `Platform.BackgroundJobs.Tests` |
| Email service (SendGrid + NoOp) | `Platform.Notifications.Tests` |
| React shared components | Frontend (Vitest) |
| Auth context and token storage | Frontend (Vitest) |
| Auth pages (Login, Callback) | Frontend (Vitest) |
| Admin management pages (Roles, Permissions) | Frontend (Vitest) |

### Out of Scope

| Area | Reason |
|------|--------|
| Real AWS Cognito calls | Require live credentials; covered by manual smoke tests |
| Real SendGrid delivery | Require live API key; NoOp service covers unit logic |
| Browser E2E (Playwright/Cypress) | Not yet introduced; future phase |
| Load / stress testing | Not yet introduced; future phase |
| Database schema migration correctness | Verified manually after `dotnet ef database update` |

---

## 5. Technology Stack

### Backend

| Tool | Purpose |
|------|---------|
| **xUnit** | Test framework |
| **FluentAssertions** | Readable assertion DSL |
| **Moq** | Interface mocking for handler tests |
| **AutoFixture** | Anonymous test data generation |
| **Bogus** | Realistic fake data (names, emails) |
| **Microsoft.AspNetCore.Mvc.Testing** | In-process HTTP server for integration tests |
| **EF Core InMemory** | Ephemeral database for repository tests |

### Frontend

| Tool | Purpose |
|------|---------|
| **Vitest** | Vite-native test runner, jest-compatible API |
| **@vitest/coverage-v8** | V8-based code coverage |
| **jsdom** | Browser DOM simulation |
| **@testing-library/react** | Component rendering and DOM queries |
| **@testing-library/user-event** | Realistic user interaction simulation |
| **@testing-library/jest-dom** | Extended DOM matchers |
| **msw** | Mock Service Worker — intercepts axios at the network layer |

---

## 6. Test Isolation Principles

### Backend

- **Domain tests**: No external dependencies. Pure factory method and value object tests only.
- **Application tests**: All repositories and external services are mocked via Moq. No EF Core or database.
- **Infrastructure tests**: Each test class gets a fresh `InMemoryDatabase` keyed by `Guid.NewGuid()`, disposed after each test class via `IDisposable`.
- **Integration tests**: `CustomWebApplicationFactory` replaces JWT authentication with `TestAuthHandler`. Real EF Core InMemory database. No external HTTP calls.

### Frontend

- MSW server is started once per test suite (`beforeAll`), handlers reset after each test (`afterEach`), and the server is shut down after all tests (`afterAll`).
- Each test file imports the MSW server from `src/test/server.ts` and overrides only the handlers it needs via `server.use(...)`.
- No real network calls are made. Any unhandled request causes a test failure (`onUnhandledRequest: 'error'`).

---

## 7. Naming Convention

All test methods follow:

```
{MethodOrScenario}_{Condition}_{ExpectedOutcome}
```

Examples:

```
Create_WithValidEmail_ReturnsEmailAddress
Handle_WithNewName_CreatesRoleAndReturnsDto
Handle_WhenNameAlreadyExists_ReturnsFailure
Validate_WithEmptyName_Fails
GetByIdAsync_WithExistingRole_ReturnsRole
GetAllUsers_WithoutToken_ReturnsUnauthorized
GetAllUsers_WithCorrectPermission_ReturnsSuccess
```

---

## 8. Coverage Targets

| Layer | Current Line Coverage | Target |
|-------|-----------------------|--------|
| `Auth.Domain` | 69.4% | 75% |
| `Auth.Application` | 37% | 50% |
| `Auth.Infrastructure` | 12.2% | 25% |
| `ApiHost` | 49.4% | 55% |
| **Overall line** | **28.1%** | **40%** |
| **Overall method** | **43.3%** | **55%** |

Coverage is measured using `dotnet test --collect:"XPlat Code Coverage"` with `reportgenerator` producing an HTML report. Test assemblies are excluded from coverage metrics.

---

## 9. Quality Gates

The following gates must pass before merging to `main`:

| Gate | Command | Pass Criteria |
|------|---------|---------------|
| Backend build | `dotnet build IFX.sln` | Zero errors |
| Backend tests | `dotnet test IFX.sln` | All 419 tests pass, 0 failures |
| Frontend tests | `npm run test:run` | All 55 tests pass, 0 failures |

No test may be marked `[Skip]` without an accompanying GitHub issue reference in a comment.

---

## 10. Test Data Management

### Builders (`IFX.Tests.Common/Builders/`)

Builders provide a fluent API for constructing domain entities with sensible defaults, reducing boilerplate across test classes:

```csharp
var user     = new UserBuilder().Active().Build();
var role     = new RoleBuilder().AsAdmin().Build();
var identity = new UserIdentityBuilder().Build();
var token    = new EmailVerificationTokenBuilder().Build();
var event_   = new LoginEventBuilder().Build();
```

### AutoFixture + AutoDomainData

`AutoDomainDataAttribute` (in `IFX.Tests.Common/Fixtures/`) combines AutoFixture with `DomainCustomization` to inject realistic test data into `[Theory]` parameters:

```csharp
[Theory, AutoDomainData]
public void SomeTest(string email, Guid id) { ... }
```

### Constants (`IFX.Tests.Common/TestConstants.cs`)

Shared string constants (`TestConstants.Roles.Admin`, `TestConstants.ValidDisplayName`, etc.) ensure assertions don't use magic strings.

---

## 11. Continuous Integration

Tests are expected to run in CI on every pull request. The recommended CI command sequence is:

```bash
dotnet restore IFX.sln
dotnet build IFX.sln --no-restore
dotnet test IFX.sln --no-build --filter "FullyQualifiedName!~IntegrationTests"
dotnet test IFX.sln --no-build  # includes integration tests
cd src/Frontend/IFX.FrontEnd && npm ci && npm run test:run
```

---

## 12. Future Testing Phases

| Phase | Description | Priority |
|-------|-------------|----------|
| E2E (Playwright) | Full browser flow: login → navigate → CRUD → logout | Medium |
| Contract tests | API contract validation between frontend and backend | Low |
| Load tests (k6) | SSO provisioning under concurrent load | Low |
| Mutation testing (Stryker.NET) | Verify test assertions are meaningful | Low |
