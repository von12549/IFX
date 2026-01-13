# AuthSamples

A production-ready ASP.NET Core 8 authentication solution with Clean Architecture, CQRS, multi-IdP support, and comprehensive audit trail.

## Features

- **Clean Architecture** - Domain, Application, Infrastructure, Presentation layers
- **CQRS Pattern** - Command/Query separation with MediatR
- **Multi-IdP Support** - Extensible identity provider architecture (AWS Cognito)
- **Role-Based Auth** - Admin, User, SsoUser roles with JWT claims transformation
- **Full Audit Trail** - Login/logout events, activity logs, registration tracking
- **195 Tests** - Comprehensive test coverage across all layers
- **Docker Support** - Containerized deployment with docker-compose

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
└── Modules/Auth/
    ├── Domain/                      # Business logic
    ├── Application/                 # Use cases (CQRS)
    ├── Infrastructure/              # Data access, AWS
    ├── Presentation/                # API endpoints
    └── Composition/                 # Module entry point
tests/                               # 195 tests
```

## API Overview

| Category | Endpoints |
|----------|-----------|
| Public | `POST /api/v1/auth/{register,confirm,login}` |
| Authenticated | `POST /api/v1/auth/{logout,refresh,revoke}`, `/api/v1/user/*` |
| Admin | `/api/v1/usermanagement/*`, `/api/v1/role/*`, `/api/v1/idp/*` |
| Health | `GET /health`, `GET /health/ready` |

See [API Reference](docs/api/endpoints.md) for full documentation.

## Development

```bash
# Build
dotnet build AuthSamples.sln

# Test (195 tests)
dotnet test AuthSamples.sln

# Run locally
cd src/ApiHost/AuthSamples.ApiHost
dotnet run
```

## Documentation

### Architecture & Development
- [Architecture Overview](docs/architecture/index.md)
- [Database Schema](docs/architecture/database.md)
- [Getting Started](docs/development/getting-started.md)
- [API Reference](docs/api/endpoints.md)

### Setup Guides
- [AWS Cognito Setup](docs/AWS_COGNITO_SETUP.md)
- [Multi-IdP Migration](docs/MULTI_IDP_MIGRATION_SUMMARY.md)

## Technology Stack

- .NET 8, ASP.NET Core 8, EF Core 8
- MediatR, FluentValidation, AutoMapper
- AWS SDK (Cognito), Serilog, Swagger
- SQL Server, Docker

## Contributing

1. Fork the repository
2. Create a feature branch
3. Submit a Pull Request

## License

MIT License
