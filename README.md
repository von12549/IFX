# AuthSamples - Modular Monolithic Authentication with AWS Cognito

A production-ready ASP.NET Core 8 authentication solution demonstrating Clean Architecture, CQRS pattern, and AWS Cognito integration with comprehensive audit trail tracking.

## Features

- **Clean Architecture**: Separation of concerns with Domain, Application, Infrastructure, and API layers
- **CQRS Pattern**: Command-Query separation using MediatR
- **AWS Cognito Integration**: Secure user authentication and authorization
- **Full Audit Trail**: Comprehensive tracking of user activities
  - User registration flow (initiated → confirmed)
  - Login/logout events with session duration
  - Activity logs for all user actions
  - IP address and device information capture
- **JWT Authentication**: Secure token-based authentication
- **FluentValidation**: Input validation with clear error messages
- **AutoMapper**: Object-to-object mapping
- **Serilog**: Structured logging to console and file
- **Swagger/OpenAPI**: Interactive API documentation
- **Docker Support**: Containerized deployment with docker-compose

## Architecture

```
AuthSamples/
├── src/
│   └── Modules/
│       └── Cognito/
│           ├── Domain/              # Business entities, value objects, interfaces
│           ├── Application/         # Use cases, DTOs, CQRS handlers
│           ├── Infrastructure/      # Data access, AWS Cognito service
│           └── API/                 # Controllers, middleware, startup
├── docs/                           # Documentation
├── docker-compose.yml              # Docker orchestration
└── README.md                       # This file
```

### Technology Stack

- **.NET 8**: Latest LTS version
- **ASP.NET Core 8**: Web API framework
- **Entity Framework Core 8**: ORM with SQL Server
- **MediatR**: CQRS and mediator pattern
- **FluentValidation**: Input validation
- **AutoMapper**: Object mapping
- **AWS SDK for .NET**: Cognito integration
- **Serilog**: Structured logging
- **Swagger/Swashbuckle**: API documentation
- **Docker**: Containerization

## Prerequisites

- [.NET 8 SDK](https://dotnet.microsoft.com/download/dotnet/8.0)
- [Docker Desktop](https://www.docker.com/products/docker-desktop) (for containerized deployment)
- [SQL Server](https://www.microsoft.com/sql-server) (or use Docker)
- [AWS Account](https://aws.amazon.com/) with Cognito access

## Quick Start

### 1. Clone the Repository

```bash
git clone <repository-url>
cd AuthSample
```

### 2. Configure AWS Cognito

Follow the detailed setup guide: [docs/AWS_COGNITO_SETUP.md](docs/AWS_COGNITO_SETUP.md)

Quick summary:
1. Create a User Pool in AWS Cognito
2. Create an App Client with secret
3. Enable authentication flows: ALLOW_USER_PASSWORD_AUTH, ALLOW_ADMIN_USER_PASSWORD_AUTH, ALLOW_REFRESH_TOKEN_AUTH
4. Note down: User Pool ID, Client ID, Client Secret, Region

### 3. Configure Application

#### Option A: Using appsettings.json (Development)

Update `src/Modules/Cognito/AuthSamples.Modules.Cognito.API/appsettings.json`:

```json
{
  "ConnectionStrings": {
    "CognitoDatabase": "Server=localhost,1433;Database=AuthSamplesDb;User Id=sa;Password=YourStrong@Passw0rd;TrustServerCertificate=True;MultipleActiveResultSets=true"
  },
  "CognitoSettings": {
    "UserPoolId": "us-east-1_XXXXXXXXX",
    "ClientId": "XXXXXXXXXXXXXXXXXXXXXXXXXX",
    "ClientSecret": "XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX",
    "Region": "us-east-1"
  }
}
```

#### Option B: Using Environment Variables (Docker)

```bash
cp .env.example .env
# Edit .env with your actual AWS Cognito settings
```

### 4. Run with Docker (Recommended)

```bash
# Start SQL Server and API
docker-compose up -d

# Check logs
docker-compose logs -f cognito-api

# Stop services
docker-compose down
```

The API will be available at: `http://localhost:5000`
Swagger UI: `http://localhost:5000/swagger`

### 5. Run Locally (Without Docker)

#### Start SQL Server

```bash
docker run -e 'ACCEPT_EULA=Y' -e 'SA_PASSWORD=YourStrong@Passw0rd' \
  -p 1433:1433 --name sqlserver \
  -d mcr.microsoft.com/mssql/server:2022-latest
```

#### Apply Database Migrations

```bash
cd src/Modules/Cognito/AuthSamples.Modules.Cognito.API
dotnet ef database update --context CognitoDbContext
```

#### Run the API

```bash
dotnet run
```

## API Endpoints

### Authentication Endpoints

#### Register User
```http
POST /api/v1/auth/register
Content-Type: application/json

{
  "email": "user@example.com",
  "password": "Test@12345",
  "username": "testuser",
  "firstName": "Test",
  "lastName": "User",
  "phoneNumber": "+1234567890" // optional
}
```

#### Confirm Registration
```http
POST /api/v1/auth/confirm
Content-Type: application/json

{
  "email": "user@example.com",
  "confirmationCode": "123456"
}
```

#### Login
```http
POST /api/v1/auth/login
Content-Type: application/json

{
  "email": "user@example.com",
  "password": "Test@12345"
}
```

Response:
```json
{
  "success": true,
  "data": {
    "accessToken": "eyJraWQiOiI...",
    "idToken": "eyJraWQiOiJ...",
    "refreshToken": "eyJjdHkiOi...",
    "expiresIn": 3600,
    "user": { ... }
  }
}
```

#### Logout (Requires Authentication)
```http
POST /api/v1/auth/logout
Authorization: Bearer <access_token>
```

### User Endpoints (All require authentication)

#### Get User Profile
```http
GET /api/v1/user/profile
Authorization: Bearer <access_token>
```

#### Get Login History
```http
GET /api/v1/user/login-history?page=1&pageSize=20
Authorization: Bearer <access_token>
```

#### Get Activity Log
```http
GET /api/v1/user/activity-log?page=1&pageSize=50
Authorization: Bearer <access_token>
```

#### Sync User Profile from Cognito
```http
POST /api/v1/user/sync
Authorization: Bearer <access_token>
```

## Database Schema

The application creates 5 tables in the `cognito` schema:

1. **Users**: Synced user profiles from Cognito
   - Unique indexes on Email, Username, CognitoUserId
2. **LoginEvents**: All login attempts with success/failure tracking
   - Stores access tokens, IP address, device info
3. **LogoutEvents**: Logout events with session duration calculation
4. **RegistrationFlowEvents**: Registration tracking from initiation to confirmation
5. **UserActivityLogs**: Comprehensive activity tracking for all user actions

## Development

### Build the Solution

```bash
dotnet build
```

### Run Tests

```bash
dotnet test
```

### Create New Migration

```bash
cd src/Modules/Cognito/AuthSamples.Modules.Cognito.Infrastructure
dotnet ef migrations add <MigrationName> --startup-project ../AuthSamples.Modules.Cognito.API
```

### Apply Migrations

```bash
dotnet ef database update --startup-project ../AuthSamples.Modules.Cognito.API
```

## Project Structure

### Domain Layer (AuthSamples.Modules.Cognito.Domain)
- **Entities**: User, LoginEvent, LogoutEvent, RegistrationFlowEvent, UserActivityLog
- **Value Objects**: CognitoUserId, EmailAddress, DeviceInfo
- **Enums**: RegistrationStatus, LoginResult, ActivityType
- **Interfaces**: Repository contracts
- **Events**: Domain events for event-driven architecture

### Application Layer (AuthSamples.Modules.Cognito.Application)
- **Commands**: RegisterUser, ConfirmRegistration, LoginUser, LogoutUser, SyncUser
- **Queries**: GetUserProfile, GetUserLoginHistory, GetUserActivityLog
- **Handlers**: Command and query handlers using MediatR
- **Validators**: FluentValidation validators
- **Behaviors**: Validation, Logging, Transaction pipeline behaviors
- **DTOs**: Data transfer objects

### Infrastructure Layer (AuthSamples.Modules.Cognito.Infrastructure)
- **Persistence**: EF Core DbContext, entity configurations, repositories
- **Services**: AWS Cognito service implementation
- **Configuration**: Settings and dependency injection

### API Layer (AuthSamples.Modules.Cognito.API)
- **Controllers**: Auth, User
- **Middleware**: Exception handling, request logging
- **Models**: Request/response models
- **Configuration**: Startup, JWT, Swagger, CORS

## Security Considerations

- **Password Policy**: Enforced by both Cognito and FluentValidation (8+ chars, uppercase, lowercase, number, special char)
- **JWT Validation**: Tokens validated against Cognito JWKS endpoint
- **HTTPS**: Required for production
- **CORS**: Configured for allowed origins
- **Token Storage**: Access and refresh tokens stored encrypted in database
- **Non-root Docker**: Container runs as non-root user (appuser)

## Monitoring and Logging

Logs are written to:
- Console (structured JSON)
- File: `logs/cognito-api-YYYYMMDD.log` (rolling daily)

Log levels:
- **Information**: Normal operations (startup, requests, responses)
- **Warning**: Failed authentication, validation errors
- **Error**: Exceptions, system errors
- **Fatal**: Application termination

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Support

For issues and questions:
- Check the [AWS Cognito Setup Guide](docs/AWS_COGNITO_SETUP.md)
- Review the [API documentation](http://localhost:5000/swagger)
- Open an issue on GitHub

## Roadmap

- [ ] Add refresh token endpoint
- [ ] Implement password reset flow
- [ ] Add email change functionality
- [ ] Implement account deletion
- [ ] Add unit and integration tests
- [ ] Add health checks
- [ ] Implement rate limiting
- [ ] Add API versioning
- [ ] Create admin endpoints
- [ ] Add user search and filtering
