# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**AuthSamples** is a production-ready ASP.NET Core 8 authentication solution demonstrating:
- **Clean Architecture** with 4 distinct layers
- **CQRS Pattern** using MediatR
- **AWS Cognito Integration** for authentication
- **Full Audit Trail** tracking all user activities
- **Docker Support** for containerized deployment

## Architecture

### Pattern: Modular Monolithic + Clean Architecture

```
AuthSamples/
├── src/Modules/Cognito/
│   ├── Domain/              # Pure business logic (no dependencies)
│   ├── Application/         # Use cases with CQRS (→ Domain)
│   ├── Infrastructure/      # Data & AWS integration (→ Application, Domain)
│   └── API/                 # HTTP endpoints (→ all layers)
├── docs/                    # Documentation
├── docker-compose.yml       # SQL Server + API orchestration
└── README.md
```

### Dependency Flow
```
API → Infrastructure → Application → Domain
                    ↘            ↗
                      MediatR
```

## Technology Stack

- **.NET 8** (LTS)
- **ASP.NET Core 8** Web API
- **Entity Framework Core 8** with SQL Server
- **MediatR** for CQRS
- **FluentValidation** for input validation
- **AutoMapper** for object mapping
- **AWS SDK for .NET** (Cognito)
- **Serilog** for structured logging
- **Swagger/Swashbuckle** for API docs
- **Docker** with multi-stage builds

## Build and Test Commands

### Build
```bash
dotnet build AuthSamples.sln                    # Build entire solution
dotnet build -c Release                         # Production build
```

### Run
```bash
# With Docker (recommended)
docker-compose up -d                            # Start services
docker-compose logs -f cognito-api              # View logs
docker-compose down                             # Stop services

# Without Docker
cd src/Modules/Cognito/AuthSamples.Modules.Cognito.API
dotnet run                                      # Run API (localhost:5000)
```

### Database
```bash
# Create migration (MUST be run from Infrastructure directory)
cd src/Modules/Cognito/AuthSamples.Modules.Cognito.Infrastructure
dotnet ef migrations add MigrationName --startup-project ../AuthSamples.Modules.Cognito.API

# Apply migrations
dotnet ef database update --startup-project ../AuthSamples.Modules.Cognito.API

# Remove last migration (if not yet applied)
dotnet ef migrations remove --startup-project ../AuthSamples.Modules.Cognito.API
```

**IMPORTANT**: Always include `--startup-project ../AuthSamples.Modules.Cognito.API` when running EF Core commands, as the DbContext is in the Infrastructure project but the startup configuration is in the API project.

## Layer Details

### Domain Layer
**Purpose**: Pure business logic with no external dependencies

**Key Components**:
- **Entities**: User, UserRole, LoginEvent, LogoutEvent, RegistrationFlowEvent, UserActivityLog
- **Value Objects**: CognitoUserId, EmailAddress, DeviceInfo (immutable, validated)
- **Enums**: RegistrationStatus, LoginResult, ActivityType
- **Repository Interfaces**: IUserRepository, IUserRoleRepository, ILoginEventRepository, etc.
- **Domain Events**: UserRegisteredDomainEvent, UserLoggedInDomainEvent, etc.

**Patterns**:
- Aggregate roots with factory methods (User.Create, UserRole.Create, LoginEvent.CreateSuccess)
- Value objects with validation (EmailAddress.Create throws on invalid email)
- Rich domain model (User.Activate(), User.UpdateProfile(), User.AssignRole(), UserRole.Update())

### Application Layer
**Purpose**: Use case orchestration with CQRS

**Key Components**:
- **Commands**: RegisterUser, ConfirmRegistration, LoginUser, LogoutUser, SyncUser, UpdateUserProfile, UpdateRole, AddRole
- **Queries**: GetUserProfile, GetUserLoginHistory, GetUserActivityLog, GetAllUsers, GetAllRoles
- **Handlers**: One handler per command/query
- **Validators**: FluentValidation (RegisterUserCommandValidator, UpdateUserProfileCommandValidator, etc.)
- **Behaviors**: ValidationBehavior, LoggingBehavior, TransactionBehavior
- **DTOs**: RegisterUserDto, LoginUserDto, UserProfileDto, UserRoleDto, etc.

**Patterns**:
- CQRS with MediatR (commands modify, queries read)
- Pipeline behaviors for cross-cutting concerns
- Result pattern for operation outcomes
- Validator auto-registration via assembly scanning

### Infrastructure Layer
**Purpose**: External system integration (database, AWS)

**Key Components**:
- **DbContext**: CognitoDbContext with 6 DbSets
- **Entity Configurations**: Fluent API (UserConfiguration, UserRoleConfiguration, LoginEventConfiguration, etc.)
- **Repositories**: UserRepository, UserRoleRepository, LoginEventRepository, etc.
- **UnitOfWork**: Transaction coordinator
- **CognitoService**: AWS SDK wrapper (SignUpAsync, AuthenticateAsync, etc.)
- **Settings**: CognitoSettings (UserPoolId, ClientId, etc.)

**Patterns**:
- Repository pattern with async/await
- Unit of Work for transaction management
- Value object conversions (CognitoUserId ↔ string)
- Owned entities (DeviceInfo inside LoginEvent)
- Auto-timestamps via IAuditableEntity in SaveChangesAsync

### API Layer
**Purpose**: HTTP interface and composition root

**Key Components**:
- **Controllers**: AuthController (public), UserController (authenticated), UserManagementController (Admin), RoleController (Admin)
- **Middleware**: ExceptionHandlingMiddleware, RequestLoggingMiddleware
- **Authorization**: UserRoleClaimsTransformation (adds database roles to JWT claims)
- **Models**: RegisterRequest, LoginRequest, UpdateUserProfileRequest, UpdateRoleRequest, AddRoleRequest, ApiResponse<T>
- **Configuration**: JWT validation, Swagger, CORS, Serilog

**Patterns**:
- Controller → MediatR handler delegation
- Consistent API responses (ApiResponse<T>)
- JWT authentication with Cognito JWKS validation
- Global exception handling with error standardization

## Database Schema

**Schema**: `cognito`

### Tables
1. **Users** (aggregate root)
   - Columns: Id (GUID), CognitoUserId, Email, Username, FirstName, LastName, PhoneNumber, EmailVerified, PhoneNumberVerified, IsActive, UserRoleId (FK), Issuer, LastSyncedAt, CreatedAt, UpdatedAt
   - Unique Indexes: Email, Username, CognitoUserId
   - Foreign Key: UserRoleId → UserRoles.Id (Restrict)

2. **UserRoles** (reference data)
   - Columns: Id (GUID), RoleName, Description, CreatedAt, UpdatedAt
   - Unique Index: RoleName
   - Seeded Roles: Admin, User, SsoUser

3. **LoginEvents**
   - Columns: Id, UserId, LoginTimestamp, Success, FailureReason, IpAddress, DeviceInfo (owned), CognitoSessionId, AccessToken, RefreshToken, TokenExpiresAt
   - Indexes: UserId, LoginTimestamp, (UserId, LoginTimestamp)

4. **LogoutEvents**
   - Columns: Id, UserId, LogoutTimestamp, SessionDuration, IpAddress, Reason
   - Indexes: UserId, LogoutTimestamp

5. **RegistrationFlowEvents**
   - Columns: Id, Email, Username, RegistrationInitiatedAt, RegistrationConfirmedAt, Status, ConfirmationCode, FailureReason, IpAddress, UserId
   - Indexes: Email, RegistrationInitiatedAt, Status

6. **UserActivityLogs**
   - Columns: Id, UserId, ActivityType, Description, Timestamp, IpAddress, Metadata (JSON)
   - Indexes: UserId, Timestamp, (UserId, Timestamp)

## Authentication Flow

### Registration
1. Client → POST /api/v1/auth/register
2. RegisterUserCommandHandler:
   - Creates user in Cognito (CognitoService.SignUpAsync)
   - Looks up default "User" role from UserRoles table
   - Creates User entity (IsActive=false, UserRoleId=User role)
   - Creates RegistrationFlowEvent (Status=Initiated)
   - Saves to database
3. User receives email with confirmation code

### Confirmation
1. Client → POST /api/v1/auth/confirm
2. ConfirmRegistrationCommandHandler:
   - Confirms user in Cognito
   - Updates User (IsActive=true)
   - Updates RegistrationFlowEvent (Status=Confirmed)

### Login
1. Client → POST /api/v1/auth/login
2. LoginUserCommandHandler:
   - Authenticates with Cognito (AdminInitiateAuthAsync)
   - Syncs user data from Cognito
   - Creates LoginEvent (with tokens, device info)
   - Creates UserActivityLog
   - Returns tokens + user profile

### Logout
1. Client → POST /api/v1/auth/logout [Authorization: Bearer <token>]
2. LogoutUserCommandHandler:
   - Extracts CognitoUserId from JWT "sub" claim
   - Looks up user in database
   - Signs out from Cognito (GlobalSignOutAsync)
   - Creates LogoutEvent (calculates session duration from last login)
   - Creates UserActivityLog

### Role-Based Authorization
- **JWT Claims Transformation**: UserRoleClaimsTransformation adds database role as ClaimTypes.Role claim to JWT principal
- **Process**: On each authenticated request, the middleware:
  1. Extracts CognitoUserId from JWT "sub" claim
  2. Queries database for user's UserRole
  3. Adds role claim to ClaimsPrincipal
- **Usage**: Enables standard ASP.NET Core [Authorize(Roles = "Admin")] attribute

## Configuration

### Required Settings (appsettings.json or .env)

```json
{
  "ConnectionStrings": {
    "CognitoDatabase": "Server=localhost,1433;Database=AuthSamplesDb;User Id=sa;Password=YourStrong@Passw0rd;TrustServerCertificate=True"
  },
  "CognitoSettings": {
    "UserPoolId": "us-east-1_XXXXXXXXX",
    "ClientId": "XXXXXXXXXXXXXXXXXXXXXXXXXX",
    "ClientSecret": "XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX",
    "Region": "us-east-1"
  }
}
```

### Setup AWS Cognito
See `docs/AWS_COGNITO_SETUP.md` for detailed instructions.

**Quick checklist**:
- [x] Create User Pool with email/username sign-in
- [x] Create App Client with secret
- [x] Enable auth flows: ALLOW_USER_PASSWORD_AUTH, ALLOW_ADMIN_USER_PASSWORD_AUTH, ALLOW_REFRESH_TOKEN_AUTH
- [x] Set password policy (8+ chars, upper, lower, number, special)
- [x] Enable self-registration and email verification

## API Endpoints

### Public Endpoints
- `POST /api/v1/auth/register` - Register new user
- `POST /api/v1/auth/confirm` - Confirm email with code
- `POST /api/v1/auth/login` - Login with email/password

### Authenticated Endpoints (require JWT token)
- `POST /api/v1/auth/logout` - Logout user
- `GET /api/v1/user/profile` - Get current user profile
- `PUT /api/v1/user/profile` - Update current user profile (partial updates)
- `GET /api/v1/user/login-history` - Get paginated login history
- `GET /api/v1/user/activity-log` - Get paginated activity log
- `POST /api/v1/user/sync` - Sync user data from Cognito

### Admin-Only Endpoints (require Admin role)
- `GET /api/v1/usermanagement/users` - Get all users (paginated)
- `PUT /api/v1/usermanagement/users/{cognitoUserId}` - Update any user profile
- `GET /api/v1/role` - Get all roles
- `PUT /api/v1/role/{roleId}` - Update role name and description
- `POST /api/v1/role` - Add new role

### Swagger UI
Available at `http://localhost:5000/swagger` with JWT Bearer authentication support.

## Key Design Decisions

### CQRS with MediatR
- **Commands**: Modify state (Register, Login, Logout) - wrapped in transactions via TransactionBehavior
- **Queries**: Read data (GetUserProfile, GetLoginHistory) - use AsNoTracking() for performance
- **Separation**: Commands publish domain events, queries are read-only projections

### Value Objects
- **CognitoUserId**: Ensures valid Cognito sub format
- **EmailAddress**: Validates email with regex
- **DeviceInfo**: Parses User-Agent string (browser, OS, device type, isBot)

### Audit Trail Strategy
- **LoginEvent**: Every login attempt (success/failure) with IP, device, tokens
- **LogoutEvent**: Session duration calculated from LoginTimestamp
- **RegistrationFlowEvent**: Track registration lifecycle (Initiated → Confirmed/Failed/Expired)
- **UserActivityLog**: General activity tracking (Registration, Login, Logout, ProfileUpdate)

### CognitoUserId vs UserId
- **Controllers**: Extract CognitoUserId from JWT "sub" claim
- **Commands/Queries**: Accept CognitoUserId (string) for authenticated endpoints
- **Handlers**: Look up User by CognitoUserId to get internal UserId (Guid)
- **Repositories**: Work with internal UserId (Guid) for performance

### User Role Management
- **Default Roles**: Admin, User, SsoUser (seeded via migrations)
- **Role Assignment**: All new users get "User" role by default during registration
- **Role Enforcement**: Claims transformation adds role from database to JWT on every request
- **Admin Access**: Only users with "Admin" role can access UserManagementController and RoleController
- **Profile Updates**:
  - Users can update their own profile via `PUT /api/v1/user/profile`
  - Admins can update any user's profile via `PUT /api/v1/usermanagement/users/{cognitoUserId}`
- **Partial Updates**: Both endpoints support partial updates (only provided fields are updated)

### Security
- **JWT Validation**: Against Cognito JWKS (Authority: https://cognito-idp.{region}.amazonaws.com/{userPoolId})
- **Password Policy**: Enforced by Cognito + FluentValidation (8+ chars, complexity)
- **Token Storage**: AccessToken and RefreshToken stored in LoginEvent (should be encrypted in production)
- **Non-root Docker**: Runs as appuser (UID 1000)
- **CORS**: Configured for specific origins (AllowAll in development)

## Logging

Serilog configuration:
- **Console**: Structured JSON logs
- **File**: `logs/cognito-api-YYYYMMDD.log` (rolling daily)

Log levels:
- **Information**: HTTP requests (method, path, status code, duration)
- **Warning**: Failed auth, validation errors
- **Error**: Exceptions, system errors
- **Fatal**: Application termination

## Docker

### Multi-stage Build
1. **Build stage**: SDK image, restore, build
2. **Publish stage**: Publish optimized artifacts
3. **Runtime stage**: Lightweight ASP.NET runtime image, non-root user

### Services
- **sqlserver**: SQL Server 2022 with health check, persistent volume
- **cognito-api**: Built from Dockerfile, depends on SQL Server health

## Common Tasks

### Add New Command
1. Create `Commands/CommandName/CommandNameCommand.cs` (record)
2. Create `Commands/CommandName/CommandNameCommandHandler.cs` (IRequestHandler)
3. Create `Commands/CommandName/CommandNameCommandValidator.cs` (AbstractValidator)
4. Auto-registered via assembly scanning

### Add New Query
1. Create `Queries/QueryName/QueryNameQuery.cs` (record)
2. Create `Queries/QueryName/QueryNameQueryHandler.cs` (IRequestHandler)
3. Auto-registered via assembly scanning

### Add New Entity
1. Create `Domain/Entities/EntityName.cs` (inherits BaseEntity)
2. Create `Infrastructure/Persistence/Configurations/EntityNameConfiguration.cs` (IEntityTypeConfiguration)
3. Add DbSet to CognitoDbContext
4. Create repository interface in Domain/Interfaces/Repositories and implementation in Infrastructure/Persistence/Repositories
5. Add repository to IUnitOfWork interface and UnitOfWork implementation
6. Register repository in Infrastructure DependencyInjection.cs
7. Create migration: `dotnet ef migrations add AddEntityName --startup-project ../AuthSamples.Modules.Cognito.API`

### Seed Reference Data in Migrations
When adding reference data (roles, statuses, etc.) that must exist before application code runs:
1. Create migration as normal
2. Modify the generated migration file's Up() method:
   ```csharp
   var roleId = Guid.NewGuid();
   var now = DateTime.UtcNow;

   migrationBuilder.InsertData(
       schema: "cognito",
       table: "TableName",
       columns: new[] { "Id", "Column1", "CreatedAt", "UpdatedAt" },
       values: new object[] { roleId, "Value1", now, now });
   ```
3. Add corresponding Down() method:
   ```csharp
   migrationBuilder.DeleteData(
       schema: "cognito",
       table: "TableName",
       keyColumn: "Column1",
       keyValue: "Value1");
   ```

## Testing Locally

```bash
# 1. Start SQL Server
docker-compose up sqlserver -d

# 2. Apply migrations
cd src/Modules/Cognito/AuthSamples.Modules.Cognito.API
dotnet ef database update --context CognitoDbContext

# 3. Run API
dotnet run

# 4. Test with curl
curl -X POST http://localhost:5000/api/v1/auth/register \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","password":"Test@12345","username":"testuser","firstName":"Test","lastName":"User"}'
```

## Troubleshooting

### Build Errors
- **NU1603 Warning**: AWS SDK version mismatch - safe to ignore, uses newer compatible version
- **Configuration binding errors**: Ensure `Microsoft.Extensions.Configuration.Binder` package is installed

### Runtime Errors
- **Database connection failed**: Check SQL Server is running and connection string is correct
- **Cognito errors**: Verify UserPoolId, ClientId, ClientSecret, Region in appsettings.json or .env
- **JWT validation failed**: Ensure Cognito Authority URL is correct

### Migration Errors
- **Startup project not specified**: Always use `--startup-project ../AuthSamples.Modules.Cognito.API`
- **DbContext not found**: Ensure you're in the Infrastructure project directory

## Completed Features

- [x] User role system (Admin, User, SsoUser)
- [x] Role-based authorization with claims transformation
- [x] User management endpoints (Admin-only)
- [x] Role management endpoints (Admin-only)
- [x] User profile update endpoints (self-service and admin)
- [x] Partial update support for user profiles
- [x] Issuer field for multi-IDP support

## Future Enhancements

Potential improvements:
- [ ] Add unit and integration tests (xUnit, FluentAssertions, Testcontainers)
- [ ] Implement refresh token endpoint
- [ ] Add password reset flow (forgot password)
- [ ] Implement email change functionality
- [ ] Add account deletion (soft delete)
- [ ] Add role assignment endpoint (change user's role)
- [ ] Add health checks (AspNetCore.HealthChecks.SqlServer, AWS)
- [ ] Implement rate limiting (AspNetCoreRateLimit)
- [ ] Add API versioning (Asp.Versioning.Mvc)
- [ ] Add distributed caching (Redis) for role lookups
- [ ] Implement event sourcing for audit trail
- [ ] Add OpenTelemetry for observability
- [ ] Add user search and filtering in admin endpoints
