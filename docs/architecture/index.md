# Architecture Overview

IFX follows a **Modular Monolithic + Clean Architecture** pattern with Minimal APIs.

## Architecture Review Baselines

- [G03 Contract/Event governance (中文)](review/gates/G03/contract-event-governance.zh-CN.md)
- [G03 Contract/Event governance (English)](review/gates/G03/contract-event-governance.en.md)
- [G03 authoritative machine-readable catalog](review/gates/G03/contract-event-catalog.yaml)
- [G05 context and sensitive-data boundary (中文)](review/gates/G05/context-sensitive-data-boundary.zh-CN.md)
- [G05 context and sensitive-data boundary (English)](review/gates/G05/context-sensitive-data-boundary.en.md)

The bilingual current-state and proposed Contracts/Adapters/Events architecture review is indexed at [review/README.md](review/README.md). Gate G01's implemented module-local transaction model is documented in [Chinese](review/gates/G01/transaction-boundary.zh-CN.md) and [English](review/gates/G01/transaction-boundary.en.md); its real Outbox/Inbox acceptance remains linked to Plan 02 E2/E4.

## Project Structure

```
IFX/
├── src/
│   ├── ApiHost/
│   │   └── IFX.ApiHost/      # Host app (middleware, startup, health checks)
│   ├── BuildingBlocks/
│   │   ├── App.Abstractions/         # Shared interfaces (IModuleInstaller, IAppMigrator)
│   │   ├── IFX.BuildingBlocks.Application/ # Shared CQRS pipeline and transaction policy
│   │   ├── IFX.BuildingBlocks.EntityFrameworkCore/ # Shared EF transaction executor
│   │   └── IFX.BuildingBlocks.Security/ # Cross-cutting security (ICurrentUser, OPA, ABAC engine, policy resolver)
│   ├── Platform/                     # Cross-cutting platform services
│   │   ├── IFX.Platform.Shared/           # Constants, settings, result pattern
│   │   ├── BackgroundJobs/                        # Hangfire-based job scheduling
│   │   │   ├── Abstractions/                      # IBackgroundJobService interface
│   │   │   ├── Infrastructure.Hangfire/           # Hangfire implementation
│   │   │   └── Composition/                       # DI registration
│   │   └── Notifications/                         # Email notifications
│   │       ├── Abstractions/                      # IEmailService interface
│   │       ├── Infrastructure.SendGrid/           # SendGrid implementation
│   │       └── Composition/                       # DI registration
│   └── Modules/Auth/
│       ├── Domain/                   # Business entities, value objects, interfaces
│       ├── Application/              # Use cases, DTOs, CQRS handlers
│       ├── Infrastructure/           # Data access, AWS Cognito service
│       ├── Presentation/             # Minimal API endpoints and models
│       └── Composition/              # Module entry point (wires all layers)
├── tests/                            # Test projects (443 backend tests)
└── docs/                             # Documentation
```

## Layer Responsibilities

### Domain Layer
- Pure business logic with no external dependencies
- Entities: User, UserIdentity, UserRole, Idp, LoginEvent, LogoutEvent, etc.
- Value Objects: Subject, EmailAddress, DeviceInfo
- Repository interfaces

### Application Layer
- Use case orchestration with CQRS (MediatR)
- Commands: RegisterUser, LoginUser, LogoutUser, RefreshToken, etc.
- Queries: GetUserProfile, GetUserLoginHistory, GetAllUsers, etc.
- Module validators and services; shared Logging, Validation, and Transaction behaviors are registered once by ApiHost

### Infrastructure Layer
- Data access (EF Core with SQL Server)
- External services (AWS Cognito)
- Repository implementations
- One keyed module transaction executor, restricted to that module's DbContext

### Presentation Layer
- Minimal API endpoints organized by feature
- Request/Response DTOs
- Extension methods for claims and HTTP context

### Composition Layer
- Module entry point implementing `IModuleInstaller`
- Wires all internal layers together
- Single project reference from ApiHost

### ApiHost Layer
- Cross-cutting concerns (auth, logging, health checks)
- Middleware pipeline configuration
- Module-agnostic composition root

## Multi-IdP Architecture

The system separates core user identity from IdP-specific data:

| Table | Purpose |
|-------|---------|
| Users | Core identity (DisplayName, IsActive, Role) |
| UserIdentities | IdP-specific attributes (Subject, Email, Names) |
| Idps | Identity Provider configurations |

**Key Design**: Users identified by `(Issuer, Subject)` tuple, not email alone.

## Technology Stack

- .NET 8, ASP.NET Core 8
- Entity Framework Core 8 with SQL Server
- MediatR for CQRS
- FluentValidation, AutoMapper
- AWS SDK for .NET (Cognito)
- Serilog, Swagger/Swashbuckle
- Docker with multi-stage builds

## Platform Services

Cross-cutting services available to all modules via the Platform layer.

### Background Jobs (Hangfire)

```csharp
// Inject IBackgroundJobService
public class MyHandler(IBackgroundJobService jobs)
{
    // Fire-and-forget
    jobs.Enqueue<IMyService>(s => s.DoWork());

    // Delayed execution
    jobs.Schedule<IMyService>(s => s.DoWork(), TimeSpan.FromMinutes(5));

    // Recurring jobs
    jobs.AddOrUpdateRecurring<IMyService>("job-id", s => s.DoWork(), "0 * * * *");
}
```

Dashboard: `/hangfire`

### Notifications (SendGrid)

```csharp
// Inject IEmailService
public class MyHandler(IEmailService email)
{
    await email.SendEmailAsync(new EmailMessage
    {
        To = "user@example.com",
        Subject = "Welcome",
        HtmlBody = "<h1>Hello</h1>"
    });

    // Templated emails
    await email.SendTemplatedEmailAsync(new TemplatedEmailMessage
    {
        To = "user@example.com",
        TemplateId = "d-abc123",
        DynamicData = new { name = "User" }
    });
}
```
