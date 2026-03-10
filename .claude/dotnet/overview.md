# .NET Overview

## Purpose
Technology stack and build/run commands for this .NET 8 solution.

---

## Technology Stack

- **.NET 8** (LTS)
- **ASP.NET Core 8** Minimal APIs
- **Entity Framework Core 8** with SQL Server
- **MediatR** for CQRS
- **FluentValidation** for input validation
- **AutoMapper** for object mapping
- **AWS SDK for .NET** (Cognito)
- **Serilog** for structured logging
- **Swagger/Swashbuckle** for API docs
- **Docker** with multi-stage builds

---

## Build Commands

```bash
# Build entire solution
dotnet build IFX.sln

# Production build
dotnet build -c Release

# Run tests
dotnet test IFX.sln
```

---

## Run Commands

```bash
# With Docker (recommended)
docker-compose up -d                    # Start services
docker-compose logs -f auth-api         # View logs
docker-compose down                     # Stop services

# Without Docker
cd src/ApiHost/IFX.ApiHost
dotnet run                              # Run API (localhost:5010)
```

---

## Local Development

**Important:** Docker SQL Server uses port **11433** on host (mapped to 1433 inside container).

```bash
# 1. Start SQL Server
docker-compose up sqlserver -d

# 2. Apply migrations
cd src/Modules/Auth/IFX.Modules.Auth.Infrastructure
dotnet ef database update --startup-project ../../../ApiHost/IFX.ApiHost

# 3. Run API
cd ../../../ApiHost/IFX.ApiHost
dotnet run
```

Connection string for local development:
```json
"AuthDatabase": "Server=localhost,11433;Database=IFXDb;User Id=sa;Password=YourStrong@Pass123;TrustServerCertificate=True"
```

---

## Docker

### Multi-stage Build
1. **Build stage**: SDK image, restore, build
2. **Publish stage**: Publish optimized artifacts
3. **Runtime stage**: Lightweight ASP.NET runtime, non-root user

### Services
- **sqlserver**: SQL Server 2022 with health check, persistent volume, port 11433
- **auth-api**: Built from Dockerfile, depends on SQL Server health

---

## Troubleshooting

| Issue | Solution |
|-------|----------|
| NU1603 Warning | AWS SDK version mismatch - safe to ignore |
| Configuration binding errors | Install `Microsoft.Extensions.Configuration.Binder` |
| Database connection failed | Check SQL Server is running, use port 11433 for Docker |
| AutoMapper errors | Ensure mapping exists in `MappingProfile.cs` |
