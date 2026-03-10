# Test Implementation Plan

## Overview

This document outlines the comprehensive testing strategy for the IFX solution, covering unit tests for all layers and integration tests for end-to-end API testing.

## Test Project Structure

```
tests/
├── IFX.Modules.Auth.Domain.Tests/           # Domain layer unit tests
├── IFX.Modules.Auth.Application.Tests/      # Application layer unit tests
├── IFX.Modules.Auth.Infrastructure.Tests/   # Infrastructure layer tests
├── IFX.Modules.Auth.Presentation.Tests/     # Presentation layer unit tests
├── IFX.IntegrationTests/                    # End-to-end API integration tests
└── IFX.Tests.Common/                        # Shared test utilities & fixtures
```

## Naming Conventions

- **Test Class Names**: `{ClassUnderTest}Tests` (e.g., `EmailAddressTests`, `RegisterUserCommandHandlerTests`)
- **Test Method Names**: `{MethodName}_{Scenario}_{ExpectedBehavior}` (e.g., `Create_WithValidEmail_ReturnsEmailAddress`)
- **Test Files**: Mirror the source file location

## Recommended Test Stack

### Core Testing

| Package | Version | Purpose |
|---------|---------|---------|
| `xUnit` | 2.6+ | Test framework |
| `xUnit.runner.visualstudio` | 2.5+ | VS Test runner |
| `FluentAssertions` | 6.12+ | Fluent assertion library |
| `Moq` | 4.20+ | Mocking framework |
| `AutoFixture` | 4.18+ | Test data generation |
| `AutoFixture.Xunit2` | 4.18+ | xUnit integration |
| `AutoFixture.AutoMoq` | 4.18+ | AutoMoq integration |
| `Bogus` | 35+ | Realistic fake data |

### Integration Testing

| Package | Version | Purpose |
|---------|---------|---------|
| `Microsoft.AspNetCore.Mvc.Testing` | 8.0+ | WebApplicationFactory for API tests |
| `Testcontainers` | 3.7+ | Docker containers for SQL Server |
| `Testcontainers.MsSql` | 3.7+ | SQL Server container |
| `Respawn` | 6.2+ | Database cleanup between tests |
| `WireMock.Net` | 1.5+ | Mock AWS Cognito HTTP calls |

### Code Coverage

| Package | Purpose |
|---------|---------|
| `coverlet.collector` | Code coverage collection |
| `coverlet.msbuild` | MSBuild integration |
| `ReportGenerator` | Coverage report generation |

## Domain Layer Unit Tests

### Value Objects

**Target Files:**
- `ValueObjects/EmailAddress.cs`
- `ValueObjects/Subject.cs`
- `ValueObjects/DeviceInfo.cs`

**EmailAddress Test Cases:**
- `Create_WithValidEmail_ReturnsEmailAddress`
- `Create_WithEmptyEmail_ThrowsArgumentException`
- `Create_WithInvalidFormat_ThrowsArgumentException`
- `Create_NormalizesToLowerCase`
- `Equals_SameEmail_ReturnsTrue`
- `Equals_DifferentEmail_ReturnsFalse`

**Subject Test Cases:**
- `Create_WithValidSubject_ReturnsSubject`
- `Create_WithEmptyValue_ThrowsArgumentException`
- `Equals_SameSubject_ReturnsTrue`

**DeviceInfo Test Cases:**
- `Parse_WithValidUserAgent_ReturnsDeviceInfo`
- `Parse_DetectsChromeBrowser`
- `Parse_DetectsWindowsOS`
- `Parse_DetectsMobileDevice`
- `Parse_DetectsBot`

### Entities

**Target Files:**
- `Entities/User.cs`
- `Entities/UserIdentity.cs`
- `Entities/UserRole.cs`
- `Entities/Idp.cs`
- `Entities/LoginEvent.cs`
- `Entities/LogoutEvent.cs`
- `Entities/RegistrationFlowEvent.cs`
- `Entities/UserActivityLog.cs`

**User Test Cases:**
- `Create_WithValidParameters_ReturnsUser`
- `Activate_SetsIsActiveTrue`
- `Deactivate_SetsIsActiveFalse`
- `UpdateDisplayName_UpdatesDisplayName`

**UserIdentity Test Cases:**
- `Create_WithValidParameters_ReturnsUserIdentity`
- `UpdateFromIdp_UpdatesAllFields`
- `UpdateProfile_PartialUpdate_OnlyUpdatesProvidedFields`

**LoginEvent Test Cases:**
- `CreateSuccess_WithValidParameters_ReturnsLoginEvent`
- `CreateFailure_SetsFailureReason`

## Application Layer Unit Tests

### Command Handlers

**Key Handlers:**
- `RegisterUserCommandHandler`
- `ConfirmRegistrationCommandHandler`
- `LoginUserCommandHandler`
- `LogoutUserCommandHandler`
- `RefreshTokenCommandHandler`
- `UpdateUserProfileCommandHandler`

**Mock Dependencies:**
- `ICognitoService`
- `IUnitOfWork`
- `IMapper`
- `ILogger<T>`

**RegisterUserCommandHandler Test Cases:**
- `Handle_WithValidRequest_CreatesUserAndUserIdentity`
- `Handle_WithExistingEmail_ReturnsFailure`
- `Handle_WhenCognitoFails_ReturnsFailure`

**LoginUserCommandHandler Test Cases:**
- `Handle_WithValidCredentials_ReturnsTokensAndUserProfile`
- `Handle_WithInvalidCredentials_ReturnsFailure`
- `Handle_CreatesLoginEvent`

### Query Handlers

**Key Handlers:**
- `GetUserProfileQueryHandler`
- `GetUserLoginHistoryQueryHandler`
- `GetAllUsersQueryHandler`
- `GetAllRolesQueryHandler`

### Validators

**Test Cases Pattern:**
- `Validate_WithValidCommand_Succeeds`
- `Validate_WithEmptyEmail_FailsWithMessage`
- `Validate_WithShortPassword_FailsWithMessage`

### Pipeline Behaviors

**ValidationBehavior Test Cases:**
- `Handle_WithValidRequest_CallsNext`
- `Handle_WithInvalidRequest_ThrowsValidationException`

**TransactionBehavior Test Cases:**
- `Handle_ForCommand_BeginsTransaction`
- `Handle_ForCommand_CommitsTransactionOnSuccess`
- `Handle_ForCommand_RollsBackTransactionOnException`

## Infrastructure Layer Tests

### Repository Tests (In-Memory Database)

**UserRepository Test Cases:**
- `GetByIdAsync_WithExistingUser_ReturnsUser`
- `GetByIssuerAndSubjectAsync_WithValidTuple_ReturnsUser`
- `GetByEmailAndIdpAsync_WithValidEmailAndIdp_ReturnsUser`
- `AddAsync_AddsUserToContext`
- `GetAllUsersAsync_ReturnsPaginatedResults`

### CognitoService Tests (Mocked AWS Client)

**Test Cases:**
- `SignUpAsync_WithValidInput_ReturnsCognitoSignUpResult`
- `AuthenticateAsync_WithValidCredentials_ReturnsCognitoAuthResult`
- `AuthenticateAsync_WhenCredentialsInvalid_ReturnsFailure`
- `RefreshTokenAsync_WithValidToken_ReturnsNewTokens`

## Presentation Layer Tests

### Endpoint Tests

**AuthEndpoints Test Cases:**
- `Register_WithValidRequest_ReturnsOkResult`
- `Register_WhenFailure_ReturnsBadRequestResult`
- `Login_WithValidCredentials_ReturnsTokens`

### Extension Method Tests

**ClaimsPrincipalExtensions Test Cases:**
- `GetIssuerAndSubject_WithValidClaims_ReturnsTuple`
- `GetIssuerAndSubject_WithMissingClaims_ReturnsNull`

## Integration Tests

### Setup

- Use `WebApplicationFactory<Program>` for API testing
- Use Testcontainers for SQL Server database
- Use WireMock.Net to mock AWS Cognito endpoints
- Use Respawn for database cleanup between tests

### API Test Scenarios

**Auth Endpoints:**
- `Register_WithValidRequest_Returns200AndCreatesUser`
- `Login_WithValidCredentials_ReturnsTokens`
- `Logout_WithValidToken_Returns200`

**User Endpoints (Authenticated):**
- `GetProfile_WithValidToken_ReturnsUserProfile`
- `GetProfile_WithoutToken_Returns401`

**Admin Endpoints:**
- `GetAllUsers_WithAdminRole_ReturnsUsers`
- `GetAllUsers_WithUserRole_Returns403`

**Health Endpoints:**
- `Health_ReturnsHealthyStatus`

## Test Data Management

### Test Data Builders

```csharp
public class UserBuilder
{
    private Guid _userRoleId = Guid.NewGuid();
    private string _displayName = "Test User";
    private bool _isActive = false;

    public UserBuilder WithRole(Guid roleId) { _userRoleId = roleId; return this; }
    public UserBuilder Active() { _isActive = true; return this; }
    public User Build() => User.Create(_userRoleId, _displayName, _isActive);
}
```

### Test Constants

```csharp
public static class TestConstants
{
    public const string ValidEmail = "test@example.com";
    public const string ValidPassword = "Test@12345";
    public const string IFXCognitoIssuer = "https://cognito-idp.ap-southeast-2.amazonaws.com/ap-southeast-2_adW7gmF5P";
}
```

## Implementation Phases

### Phase 1: Foundation
- Create test project structure
- Add NuGet packages
- Create shared utilities (builders, fixtures, constants)
- Implement Domain value object tests

### Phase 2: Domain & Application
- Complete Domain entity tests
- Implement Application validator tests
- Implement command/query handler tests

### Phase 3: Infrastructure & Presentation
- Implement repository tests (in-memory DB)
- Implement CognitoService tests (mocked AWS)
- Implement endpoint tests
- Implement middleware tests

### Phase 4: Integration Tests
- Set up Testcontainers infrastructure
- Set up WireMock for Cognito
- Implement API integration tests

### Phase 5: CI/CD & Polish
- Configure GitHub Actions workflow
- Add code coverage reporting
- Fill coverage gaps

## Coverage Targets

| Layer | Target |
|-------|--------|
| Domain | 95%+ |
| Application | 85%+ |
| Infrastructure | 80%+ |
| Presentation | 75%+ |
| **Overall** | **80%+** |

## CI/CD Configuration

### GitHub Actions Workflow

```yaml
name: Tests

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  unit-tests:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-dotnet@v4
        with:
          dotnet-version: '8.0.x'
      - run: dotnet restore
      - run: dotnet test tests/**/*.Tests.csproj --collect:"XPlat Code Coverage"
      - uses: codecov/codecov-action@v3

  integration-tests:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-dotnet@v4
        with:
          dotnet-version: '8.0.x'
      - run: dotnet test tests/IFX.IntegrationTests
```

## Key Challenges and Mitigations

| Challenge | Mitigation |
|-----------|------------|
| AWS Cognito Mocking | Use WireMock.Net for HTTP; mock `IAmazonCognitoIdentityProvider` for unit tests |
| Multi-IdP Lookup | Create helper methods for consistent `(Issuer, Subject)` pairs |
| Database Cleanup | Use Respawn library to reset state between tests |
| Transaction Testing | Use in-memory DB for unit tests; real SQL container for integration |
