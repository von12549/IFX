# Testing

## Purpose
Testing approach, project structure, and patterns.

---

## Test Projects

### Auth Module Tests (178 tests)

| Project | Purpose | Tests |
|---------|---------|-------|
| `AuthSamples.Tests.Common` | Shared utilities, builders, fixtures | - |
| `AuthSamples.Modules.Auth.Domain.Tests` | Entity and value object tests | 96 |
| `AuthSamples.Modules.Auth.Application.Tests` | Validator and behavior tests | 63 |
| `AuthSamples.Modules.Auth.Infrastructure.Tests` | Repository tests | 9 |
| `AuthSamples.Modules.Auth.Presentation.Tests` | Extension method tests | 10 |

### Platform Module Tests (28 tests)

| Project | Purpose | Tests |
|---------|---------|-------|
| `AuthSamples.Platform.BackgroundJobs.Tests` | Hangfire service tests | 11 |
| `AuthSamples.Platform.Notifications.Tests` | Email service tests | 17 |

### Integration Tests

| Project | Purpose | Tests |
|---------|---------|-------|
| `AuthSamples.IntegrationTests` | End-to-end API tests | 17 |

**Total: 206 unit tests + 17 integration tests**

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

## Platform Tests

### BackgroundJobs Tests

Tests `HangfireBackgroundJobService` with mocked `IBackgroundJobClient` and `IRecurringJobManager`:

```csharp
public class HangfireBackgroundJobServiceTests
{
    private readonly Mock<IBackgroundJobClient> _mockJobClient;
    private readonly Mock<IRecurringJobManager> _mockRecurringJobManager;
    private readonly HangfireBackgroundJobService _sut;

    [Fact]
    public void Enqueue_WithSyncAction_CallsBackgroundJobClient()
    {
        // Arrange
        _mockJobClient.Setup(x => x.Create(It.IsAny<Job>(), It.IsAny<IState>()))
            .Returns("job-123");

        // Act
        var jobId = _sut.Enqueue<ITestService>(x => x.DoWork());

        // Assert
        Assert.Equal("job-123", jobId);
    }
}
```

**Coverage:**
- `Enqueue` - sync and async actions
- `Schedule` - TimeSpan and DateTimeOffset overloads
- `AddOrUpdateRecurring` - cron-based jobs
- `RemoveRecurring`, `TriggerRecurring`
- `Delete` - job deletion

### Notifications Tests

Tests `SendGridEmailService` and `NoOpEmailService`:

```csharp
public class SendGridEmailServiceTests
{
    private readonly Mock<ISendGridClient> _mockClient;
    private readonly SendGridEmailService _sut;

    [Fact]
    public async Task SendEmailAsync_WhenSuccessful_ReturnsSuccess()
    {
        // Arrange
        var message = new EmailMessage { To = "test@example.com", Subject = "Test" };
        _mockClient.Setup(x => x.SendEmailAsync(It.IsAny<SendGridMessage>(), It.IsAny<CancellationToken>()))
            .ReturnsAsync(CreateMockResponse(HttpStatusCode.Accepted, "msg-123"));

        // Act
        var result = await _sut.SendEmailAsync(message);

        // Assert
        Assert.True(result.IsSuccess);
    }
}
```

**SendGridEmailService Coverage:**
- `SendEmailAsync` - success, failure, exception handling
- From address handling (default vs custom)
- CC/BCC recipients
- `SendTemplatedEmailAsync` - template ID and data
- `SendBatchAsync` - multiple messages with individual results

**NoOpEmailService Coverage:**
- Always returns success
- Logs message details without sending

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
# All unit tests (excludes integration tests)
dotnet test AuthSamples.sln --filter "FullyQualifiedName!~IntegrationTests"

# All tests including integration
dotnet test AuthSamples.sln

# Specific project
dotnet test tests/AuthSamples.Modules.Auth.Domain.Tests

# Platform tests only
dotnet test tests/AuthSamples.Platform.BackgroundJobs.Tests
dotnet test tests/AuthSamples.Platform.Notifications.Tests

# With coverage
dotnet test --collect:"XPlat Code Coverage"

# Verbose output
dotnet test --verbosity normal
```
