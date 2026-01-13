# Testing

## Purpose
Testing approach, project structure, and patterns.

---

## Test Projects

| Project | Purpose | Tests |
|---------|---------|-------|
| `AuthSamples.Tests.Common` | Shared utilities, builders, fixtures | - |
| `AuthSamples.Modules.Auth.Domain.Tests` | Entity and value object tests | 96 |
| `AuthSamples.Modules.Auth.Application.Tests` | Validator and behavior tests | 63 |
| `AuthSamples.Modules.Auth.Infrastructure.Tests` | Repository tests | 9 |
| `AuthSamples.Modules.Auth.Presentation.Tests` | Extension method tests | 10 |
| `AuthSamples.IntegrationTests` | End-to-end API tests | 17 |

---

## Technology Stack

- **xUnit** - Test framework
- **FluentAssertions** - Assertion library
- **Moq** - Mocking framework
- **AutoFixture** - Test data generation
- **Bogus** - Realistic fake data
- **Microsoft.AspNetCore.Mvc.Testing** - Integration testing
- **EF Core InMemory** - Database testing

---

## Test Naming Convention

```
{MethodName}_{Scenario}_{ExpectedBehavior}
```

Examples:
- `Create_WithValidEmail_ReturnsEmailAddress`
- `Parse_WithEmptyUserAgent_ReturnsUnknownDeviceInfo`
- `Handle_WithInvalidRequest_ThrowsValidationException`

---

## Builders (Test Data)

Located in `Tests.Common/Builders/`:

```csharp
// Create test user
var user = new UserBuilder()
    .WithDisplayName("Test User")
    .Active()
    .Build();

// Create with specific role
var adminUser = new UserBuilder()
    .WithRole(adminRoleId)
    .Active()
    .Build();
```

---

## Integration Tests

Uses `CustomWebApplicationFactory` to:
- Replace DbContext with InMemory database
- Mock ICognitoService
- Skip migrations
- Seed test data (UserRoles, Idps)

```csharp
public class AuthEndpointTests : IClassFixture<CustomWebApplicationFactory>
{
    private readonly HttpClient _client;

    public AuthEndpointTests(CustomWebApplicationFactory factory)
    {
        _client = factory.CreateClient();
    }

    [Fact]
    public async Task Login_WithInvalidCredentials_ReturnsUnauthorized()
    {
        var response = await _client.PostAsJsonAsync("/api/v1/auth/login", request);
        response.StatusCode.Should().Be(HttpStatusCode.Unauthorized);
    }
}
```

---

## Run Tests

```bash
# All tests
dotnet test AuthSamples.sln

# Specific project
dotnet test tests/AuthSamples.Modules.Auth.Domain.Tests

# With coverage
dotnet test --collect:"XPlat Code Coverage"
```
