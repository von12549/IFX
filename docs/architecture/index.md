# Architecture Overview

AuthSamples follows a **Modular Monolithic + Clean Architecture** pattern with Minimal APIs.

## Project Structure

```
AuthSamples/
├── src/
│   ├── ApiHost/
│   │   └── AuthSamples.ApiHost/      # Host app (middleware, startup, health checks)
│   ├── BuildingBlocks/
│   │   └── App.Abstractions/         # Shared interfaces (IModuleInstaller, IAppMigrator)
│   └── Modules/Auth/
│       ├── Domain/                   # Business entities, value objects, interfaces
│       ├── Application/              # Use cases, DTOs, CQRS handlers
│       ├── Infrastructure/           # Data access, AWS Cognito service
│       ├── Presentation/             # Minimal API endpoints and models
│       └── Composition/              # Module entry point (wires all layers)
├── tests/                            # Test projects (195 tests)
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
- Validators (FluentValidation), Pipeline behaviors

### Infrastructure Layer
- Data access (EF Core with SQL Server)
- External services (AWS Cognito)
- Repository implementations

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
