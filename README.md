# AuthSamples

A production-ready ASP.NET Core 8 authentication solution with Clean Architecture, CQRS, dynamic multi-IdP SSO, and comprehensive audit trail.

## Features

- **Clean Architecture** - Domain, Application, Infrastructure, Presentation layers
- **CQRS Pattern** - Command/Query separation with MediatR
- **OAuth 2.0 with PKCE** - Cognito Managed Login (Hosted UI) integration
- **Dynamic Multi-IdP SSO** - Database-driven IdP configuration with auto-provisioning
- **OIDC Discovery** - Automatic IdP configuration via well-known endpoints
- **UserInfo-Based Provisioning** - Fetches user data from OIDC userinfo endpoint during auto-provisioning
- **Role-Based Auth** - Admin, User, SsoUser, Pending roles with JWT claims transformation
- **Full Audit Trail** - Login/logout events, activity logs, registration tracking
- **Platform Services** - Background jobs (Hangfire), Email notifications (SendGrid)
- **195 Tests** - Comprehensive test coverage across all layers
- **Docker Support** - Containerized deployment with docker-compose
- **Demo UI** - Simple HTML/JS client for testing OAuth flow

## Quick Start

```bash
# Clone and configure
git clone <repository-url>
cd AuthSample

# Run with Docker
docker-compose up -d

# Access
# API: http://localhost:5000
# Swagger: http://localhost:5000/swagger
```

See [Getting Started](docs/development/getting-started.md) for detailed setup.

## Project Structure

```
src/
├── ApiHost/AuthSamples.ApiHost/     # Host application
├── BuildingBlocks/App.Abstractions/ # Shared interfaces
├── WebUI/AuthSamples.WebUI/         # Demo OAuth client (HTML/JS)
├── Modules/Auth/
│   ├── Domain/                      # Business logic
│   ├── Application/                 # Use cases (CQRS)
│   ├── Infrastructure/              # Data access, AWS, OIDC
│   ├── Presentation/                # API endpoints
│   └── Composition/                 # Module entry point
└── Platform/
    ├── AuthSamples.Platform.Shared/ # Common platform types
    ├── BackgroundJobs/              # Hangfire background job service
    │   ├── Abstractions/            # IBackgroundJobService
    │   ├── Infrastructure.Hangfire/ # Hangfire implementation
    │   └── Composition/             # DI registration
    └── Notifications/               # SendGrid email service
        ├── Abstractions/            # IEmailService
        ├── Infrastructure.SendGrid/ # SendGrid implementation
        └── Composition/             # DI registration
tests/                               # 195 tests
```

## API Overview

| Category | Endpoints |
|----------|-----------|
| **OAuth** | `GET /api/v1/auth/oauth/{authorize,callback,userinfo,logout}` |
| Public | `POST /api/v1/auth/{register,confirm,login}` |
| Authenticated | `POST /api/v1/auth/{logout,refresh,revoke}`, `/api/v1/user/*` |
| Admin | `/api/v1/usermanagement/*`, `/api/v1/role/*`, `/api/v1/idp/*` |
| Health | `GET /health`, `GET /health/ready` |
| Jobs | `GET /hangfire` (dashboard) |

### OAuth Flow (Recommended)

```
GET /api/v1/auth/oauth/authorize?response_mode=json
→ Returns { authorizationUrl, state }
→ Redirect user to authorizationUrl (Cognito Hosted UI)
→ After login, redirects to callback with tokens
```

See [API Reference](docs/api/endpoints.md) for full documentation.

## Platform Services

### Background Jobs (Hangfire)

```csharp
public class MyService
{
    private readonly IBackgroundJobService _jobs;

    public void ScheduleWork()
    {
        // Fire-and-forget
        _jobs.Enqueue<IEmailService>(x => x.SendEmailAsync(message));

        // Delayed
        _jobs.Schedule<IReportService>(x => x.Generate(), TimeSpan.FromHours(1));

        // Recurring (cron)
        _jobs.AddOrUpdateRecurring<ICleanupService>("cleanup", x => x.Run(), "0 0 * * *");
    }
}
```

### Email Notifications (SendGrid)

```csharp
public class MyService
{
    private readonly IEmailService _email;

    public async Task SendWelcome(string userEmail)
    {
        await _email.SendEmailAsync(new EmailMessage
        {
            To = userEmail,
            Subject = "Welcome!",
            HtmlBody = "<h1>Welcome to our app!</h1>"
        });
    }
}
```

Configuration in `appsettings.json`:
```json
{
  "BackgroundJobs": { "ConnectionString": "..." },
  "Notifications": {
    "SendGrid": {
      "ApiKey": "SG.xxx",
      "DefaultFromEmail": "noreply@example.com"
    }
  }
}
```

## Development

```bash
# Build
dotnet build AuthSamples.sln

# Test (195 tests)
dotnet test AuthSamples.sln

# Run API locally
cd src/ApiHost/AuthSamples.ApiHost
dotnet run

# Run Demo UI (optional)
cd src/WebUI/AuthSamples.WebUI
python -m http.server 3000
# Open http://localhost:3000
```

## Documentation

### Architecture & Development
- [Architecture Overview](docs/architecture/index.md)
- [Database Schema](docs/architecture/database.md)
- [Getting Started](docs/development/getting-started.md)
- [API Reference](docs/api/endpoints.md)

### Setup Guides
- [Cognito Managed Login (OAuth)](docs/Plans/cognito-managed-login.md)
- [SSO Multi-IdP Authentication](docs/sso-multi-idp.md)
- [Auto-Provisioning Strategy](docs/architecture/auto-provisioning.md)
- [AWS Cognito Setup](docs/AWS_COGNITO_SETUP.md)
- [Multi-IdP Migration](docs/MULTI_IDP_MIGRATION_SUMMARY.md)

## Technology Stack

- .NET 8, ASP.NET Core 8, EF Core 8
- MediatR, FluentValidation, AutoMapper
- AWS SDK (Cognito), Serilog, Swagger
- Hangfire (background jobs), SendGrid (email)
- SQL Server, Docker

## Contributing

1. Fork the repository
2. Create a feature branch
3. Submit a Pull Request

## License

MIT License
