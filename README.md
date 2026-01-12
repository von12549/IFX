# AuthSamples - Multi-IdP Authentication with Clean Architecture

A production-ready ASP.NET Core 8 authentication solution demonstrating Clean Architecture, CQRS pattern, multi-IdP support with AWS Cognito, and comprehensive audit trail tracking.

## ✨ Latest Updates (January 2026)

**🎉 Multi-IdP Architecture**: Complete migration to support multiple identity providers
- Users can link accounts from multiple IdPs (currently Cognito, extensible to Google, Azure AD, etc.)
- Unique identification via `(Issuer, Subject)` tuple across all IdPs
- IdP-scoped email validation prevents duplicate emails per provider
- See [Migration Documentation](docs/MULTI_IDP_MIGRATION_SUMMARY.md) for technical details

## Features

- **Clean Architecture**: Separation of concerns with Domain, Application, Infrastructure, Presentation, and ApiHost layers
- **CQRS Pattern**: Command-Query separation using MediatR
- **Multi-IdP Support**: Extensible architecture supporting multiple identity providers
- **AWS Cognito Integration**: Primary IdP with secure user authentication
- **Role-Based Authorization**: Admin, User, and SsoUser roles with JWT claims transformation
- **Full Audit Trail**: Comprehensive tracking of user activities
  - User registration flow (initiated → confirmed)
  - Login/logout events with session duration
  - Activity logs for all user actions
  - IP address and device information capture
- **JWT Authentication**: Secure token-based authentication with refresh tokens
- **OAuth 2.0 Token Management**: Refresh and revoke token endpoints
- **FluentValidation**: Input validation with clear error messages
- **AutoMapper**: Object-to-object mapping
- **Serilog**: Structured logging to console and file
- **Swagger/OpenAPI**: Interactive API documentation with Bearer auth
- **Health Checks**: SQL Server and AWS Cognito connectivity monitoring
- **Docker Support**: Containerized deployment with docker-compose

## Architecture

```
AuthSamples/
├── src/
│   ├── ApiHost/
│   │   └── AuthSamples.ApiHost/    # Infrastructure, middleware, startup (top-level, module-agnostic)
│   └── Modules/
│       └── Auth/                   # Main authentication module
│           ├── Domain/             # Business entities, value objects, interfaces
│           ├── Application/        # Use cases, DTOs, CQRS handlers
│           ├── Infrastructure/     # Data access, AWS Cognito service
│           └── Presentation/       # Minimal API endpoints and models
├── docs/                          # Documentation
│   ├── AWS_COGNITO_SETUP.md      # Cognito configuration guide
│   └── MULTI_IDP_MIGRATION_SUMMARY.md  # Multi-IdP architecture details
├── docker-compose.yml             # Docker orchestration
└── README.md                      # This file
```

### Multi-IdP Architecture

The system separates core user identity from IdP-specific data:
- **Users** table: Core identity (DisplayName, IsActive, Role)
- **UserIdentities** table: IdP-specific attributes (Subject, Email, Names, Phone)
- **Idps** table: Identity Provider configurations
- **Relationship**: One User → Many UserIdentities (one per linked IdP)

Benefits:
- Users can link multiple IdP accounts (e.g., Cognito + Google SSO)
- Same email can exist across different IdPs
- Add new IdPs without code changes (configuration only)

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

Update `src/ApiHost/AuthSamples.ApiHost/appsettings.json`:

```json
{
  "ConnectionStrings": {
    "AuthDatabase": "Server=localhost,1433;Database=AuthSamplesDb;User Id=sa;Password=YourStrong@Passw0rd;TrustServerCertificate=True;MultipleActiveResultSets=true"
  },
  "CognitoSettings": {
    "UserPoolId": "ap-southeast-2_adW7gmF5P",
    "ClientId": "XXXXXXXXXXXXXXXXXXXXXXXXXX",
    "ClientSecret": "XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX",
    "Region": "ap-southeast-2"
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
docker-compose logs -f auth-api

# Stop services
docker-compose down
```

The API will be available at: `http://localhost:5000`
Swagger UI: `http://localhost:5000/swagger`

### 5. Run Locally (Without Docker)

#### Start SQL Server

```bash
docker run -e 'ACCEPT_EULA=Y' -e 'SA_PASSWORD=YourStrong@Pass123' \
  -p 1433:1433 --name sqlserver \
  -d mcr.microsoft.com/mssql/server:2022-latest
```

#### Apply Database Migrations

```bash
cd src/Modules/Auth/AuthSamples.Modules.Auth.Infrastructure
dotnet ef database update --startup-project ../../../ApiHost/AuthSamples.ApiHost
```

#### Run the API

```bash
cd src/ApiHost/AuthSamples.ApiHost
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
  "birthDate": "1990-01-01",
  "phoneNumber": "+61412345678"
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

#### Refresh Token
```http
POST /api/v1/auth/refresh
Content-Type: application/json

{
  "email": "user@example.com",
  "refreshToken": "eyJjdHkiOi..."
}
```

#### Revoke Token
```http
POST /api/v1/auth/revoke
Content-Type: application/json

{
  "refreshToken": "eyJjdHkiOi..."
}
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

#### Update User Profile
```http
PUT /api/v1/user/profile
Authorization: Bearer <access_token>
Content-Type: application/json

{
  "firstName": "Updated",
  "lastName": "Name",
  "phoneNumber": "+61412345679"
}
```

### Admin Endpoints (Require Admin role)

#### Get All Users
```http
GET /api/v1/usermanagement/users?page=1&pageSize=20
Authorization: Bearer <admin_access_token>
```

#### Update User Profile (Admin)
```http
PUT /api/v1/usermanagement/users/{userId}
Authorization: Bearer <admin_access_token>
Content-Type: application/json

{
  "firstName": "Updated",
  "lastName": "Name"
}
```

#### Get All Roles
```http
GET /api/v1/role
Authorization: Bearer <admin_access_token>
```

#### Add New Role
```http
POST /api/v1/role
Authorization: Bearer <admin_access_token>
Content-Type: application/json

{
  "roleName": "Manager",
  "description": "Manager role with elevated permissions"
}
```

#### Update Role
```http
PUT /api/v1/role/{roleId}
Authorization: Bearer <admin_access_token>
Content-Type: application/json

{
  "roleName": "UpdatedManager",
  "description": "Updated description"
}
```

#### Get All Identity Providers
```http
GET /api/v1/idp
Authorization: Bearer <admin_access_token>
```

#### Create Identity Provider
```http
POST /api/v1/idp
Authorization: Bearer <admin_access_token>
Content-Type: application/json

{
  "name": "Google SSO",
  "issuer": "https://accounts.google.com",
  "authority": "https://accounts.google.com",
  "description": "Google Single Sign-On",
  "enabled": true
}
```

#### Update Identity Provider
```http
PUT /api/v1/idp/{idpId}
Authorization: Bearer <admin_access_token>
Content-Type: application/json

{
  "name": "Google SSO Updated",
  "enabled": false
}
```

## Database Schema

The application creates 8 tables in the `auth` schema:

### Core Tables

1. **Users**: Core user identity
   - Id, DisplayName, IsActive, UserRoleId, timestamps
   - Separated from IdP-specific data for multi-IdP support

2. **UserIdentities**: IdP-specific user attributes
   - UserId (FK), IdpId (FK), Issuer, Subject, Email, EmailVerified
   - FirstName, LastName, BirthDate, PhoneNumber, PhoneNumberVerified
   - Unique constraint on (Issuer, Subject)
   - One user can have multiple identities from different IdPs

3. **UserRoles**: Role definitions
   - Seeded roles: Admin, User, SsoUser
   - Used for role-based authorization

4. **Idps**: Identity Provider configurations
   - Name, Issuer (unique), Authority, Enabled, AutoProvisionEnabled
   - Configuration for JWT validation and claims mapping
   - Seeded with IFX Cognito

### Audit Tables

5. **LoginEvents**: All login attempts with success/failure tracking
   - Stores access tokens, IP address, device info

6. **LogoutEvents**: Logout events with session duration calculation

7. **RegistrationFlowEvents**: Registration tracking from initiation to confirmation

8. **UserActivityLogs**: Comprehensive activity tracking for all user actions

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
cd src/Modules/Auth/AuthSamples.Modules.Auth.Infrastructure
dotnet ef migrations add <MigrationName> --startup-project ../../../ApiHost/AuthSamples.ApiHost
```

### Apply Migrations

```bash
cd src/Modules/Auth/AuthSamples.Modules.Auth.Infrastructure
dotnet ef database update --startup-project ../../../ApiHost/AuthSamples.ApiHost
```

## Project Structure

### Domain Layer (AuthSamples.Modules.Auth.Domain)
- **Entities**: User, UserIdentity, UserRole, Idp, LoginEvent, LogoutEvent, RegistrationFlowEvent, UserActivityLog
- **Value Objects**: Subject, EmailAddress, DeviceInfo
- **Enums**: RegistrationStatus, LoginResult, ActivityType
- **Repository Interfaces**: IUserRepository, IUserIdentityRepository, IUserRoleRepository, IIdpRepository, etc.
- **Domain Events**: UserRegisteredDomainEvent, UserLoggedInDomainEvent, etc.

### Application Layer (AuthSamples.Modules.Auth.Application)
- **Commands**: RegisterUser, ConfirmRegistration, LoginUser, LogoutUser, RefreshToken, RevokeToken, SyncUser, UpdateUserProfile, AddRole, UpdateRole, CreateIdp, UpdateIdp
- **Queries**: GetUserProfile, GetUserLoginHistory, GetUserActivityLog, GetAllUsers, GetAllRoles, GetAllIdps
- **Handlers**: Command and query handlers using MediatR (one per command/query)
- **Validators**: FluentValidation validators for all commands
- **Behaviors**: Validation, Logging, Transaction pipeline behaviors
- **DTOs**: UserProfileDto, LoginUserDto, UserRoleDto, IdpDto, etc.
- **Mappings**: AutoMapper profiles

### Infrastructure Layer (AuthSamples.Modules.Auth.Infrastructure)
- **Persistence**:
  - AuthDbContext (EF Core DbContext with 8 DbSets)
  - Entity configurations (UserConfiguration, UserIdentityConfiguration, etc.)
  - Repositories (UserRepository, UserIdentityRepository, etc.)
  - UnitOfWork pattern for transaction management
- **Services**: CognitoService (AWS SDK wrapper)
- **Configuration**: CognitoSettings, dependency injection

### Presentation Layer (AuthSamples.Modules.Auth.Presentation)
- **Endpoints**: Minimal API endpoint modules organized by feature (Auth, User, UserManagement, Role, Idp)
- **Endpoint Extensions**: MapAuthEndpoints, MapUserEndpoints, MapUserManagementEndpoints, MapRoleEndpoints, MapIdpEndpoints
- **Models**: Request/response models organized by feature (RegisterRequest, LoginRequest, ApiResponse<T>, etc.)
- **Helper Extensions**: ClaimsPrincipalExtensions (extract issuer/subject), HttpContextExtensions (get IP address)
- **Master Registration**: PresentationExtensions.MapAuthModuleEndpoints() for unified endpoint registration

### ApiHost Layer (AuthSamples.ApiHost)
- **Location**: Top-level `src/ApiHost/AuthSamples.ApiHost/` (module-agnostic)
- **Configuration Modules**: AuthenticationConfiguration, SwaggerConfiguration, CorsConfiguration, HealthCheckConfiguration
- **Authorization**: UserRoleClaimsTransformation (JWT claims enrichment)
- **Middleware**: ExceptionHandlingMiddleware, RequestLoggingMiddleware
- **Health Checks**: CognitoHealthCheck for AWS Cognito connectivity monitoring
- **Program.cs**: Application startup with JWT validation, Swagger, CORS, Serilog, Health Checks, and EF Core migrations
- **Design**: Module-agnostic composition root that can host multiple modules in the future

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

## Completed Features

- [x] **Presentation + ApiHost Architecture** (January 2026) - Migrated from controller-based API to Minimal APIs with separated concerns
- [x] **Multi-IdP Architecture** (January 2026) - User + UserIdentity table separation
- [x] **Issuer+Subject Lookup Pattern** - All handlers use `(Issuer, Subject)` tuple
- [x] **IdP-Scoped Email Lookup** - Prevents duplicate emails across different IdPs
- [x] **Refresh Token Endpoint** - OAuth 2.0 token refresh
- [x] **Revoke Token Endpoint** - Token revocation for security
- [x] **Health Checks** - SQL Server and AWS Cognito monitoring
- [x] **Admin Endpoints** - User, Role, and IdP management
- [x] **Role-Based Authorization** - Admin, User, SsoUser roles
- [x] **User Management** - Admin can view and update all users
- [x] **Role Management** - Admin can create and update roles
- [x] **IdP Management** - Admin can configure identity providers

## Roadmap

- [ ] **Additional IdP Integration** (Google SSO, Azure AD, Okta, Auth0)
- [ ] **Account Linking UI** - Allow users to link multiple IdP accounts
- [ ] Implement password reset flow (forgot password)
- [ ] Add email change functionality
- [ ] Implement account deletion (soft delete)
- [ ] Add role assignment endpoint (change user's role)
- [ ] Add unit and integration tests (xUnit, FluentAssertions, Testcontainers)
- [ ] Implement rate limiting (AspNetCoreRateLimit)
- [ ] Add API versioning (Asp.Versioning.Mvc)
- [ ] Add distributed caching (Redis) for role lookups
- [ ] Implement event sourcing for audit trail
- [ ] Add OpenTelemetry for observability
- [ ] Add user search and filtering in admin endpoints

## Documentation

- **[CLAUDE.md](CLAUDE.md)** - Comprehensive guide for Claude Code with architecture details and patterns
- **[AWS Cognito Setup](docs/AWS_COGNITO_SETUP.md)** - Step-by-step Cognito configuration guide
- **[Multi-IdP Migration Summary](docs/MULTI_IDP_MIGRATION_SUMMARY.md)** - Complete 3-phase migration documentation (440+ lines)
