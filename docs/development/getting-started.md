# Getting Started

## Prerequisites

- [.NET 8 SDK](https://dotnet.microsoft.com/download/dotnet/8.0)
- [Docker Desktop](https://www.docker.com/products/docker-desktop)
- [AWS Account](https://aws.amazon.com/) with Cognito access

## Quick Start with Docker

```bash
# 1. Clone and configure
git clone <repository-url>
cd AuthSample
cp .env.example .env
# Edit .env with your AWS Cognito settings

# 2. Start services
docker-compose up -d

# 3. Access the API
# API: http://localhost:5010
# Swagger: http://localhost:5010/swagger
```

## Local Development (Without Docker)

### 1. Start SQL Server

```bash
docker run -e 'ACCEPT_EULA=Y' -e 'SA_PASSWORD=YourStrong@Pass123' \
  -p 11433:1433 --name sqlserver \
  -d mcr.microsoft.com/mssql/server:2022-latest
```

### 2. Configure Application

Update `src/ApiHost/IFX.ApiHost/appsettings.Development.json`:

```json
{
  "ConnectionStrings": {
    "AuthDatabase": "Server=localhost,11433;Database=IFXDb;User Id=sa;Password=YourStrong@Pass123;TrustServerCertificate=True"
  },
  "CognitoSettings": {
    "UserPoolId": "your-user-pool-id",
    "ClientId": "your-client-id",
    "ClientSecret": "your-client-secret",
    "Region": "ap-southeast-2"
  }
}
```

### 3. Apply Migrations

```bash
cd src/Modules/Auth/IFX.Modules.Auth.Infrastructure
dotnet ef database update --startup-project ../../../ApiHost/IFX.ApiHost
```

### 4. Run the API

```bash
cd src/ApiHost/IFX.ApiHost
dotnet run
```

## Build and Test

```bash
# Build
dotnet build IFX.sln

# Run all 195 tests
dotnet test IFX.sln

# Run specific test project
dotnet test tests/IFX.Modules.Auth.Domain.Tests
```

## AWS Cognito Setup

See [AWS_COGNITO_SETUP.md](../AWS_COGNITO_SETUP.md) for detailed configuration.

Quick checklist:
1. Create User Pool with email/username sign-in
2. Create App Client with secret
3. Enable auth flows: ALLOW_USER_PASSWORD_AUTH, ALLOW_ADMIN_USER_PASSWORD_AUTH, ALLOW_REFRESH_TOKEN_AUTH
4. Note: User Pool ID, Client ID, Client Secret, Region
