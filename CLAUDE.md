# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**AuthSamples** is a production-ready ASP.NET Core 8 authentication solution demonstrating:
- **Clean Architecture** with 4 distinct layers
- **CQRS Pattern** using MediatR
- **Multi-IdP Support** with AWS Cognito as primary provider
- **Full Audit Trail** tracking all user activities
- **Docker Support** for containerized deployment

**🎉 Multi-IdP Architecture** (Updated January 2026):
- Users can have multiple identities from different providers
- Unique identification via `(Issuer, Subject)` tuple
- Separation of core identity (User) from IdP-specific data (UserIdentity)
- See `docs/MULTI_IDP_MIGRATION_SUMMARY.md` for migration details

## Architecture

### Pattern: Modular Monolithic + Clean Architecture + Minimal APIs

```
AuthSamples/
├── src/
│   ├── ApiHost/
│   │   └── AuthSamples.ApiHost/      # Infrastructure & composition root
│   └── Modules/Auth/
│       ├── Domain/                   # Pure business logic (no dependencies)
│       ├── Application/              # Use cases with CQRS (→ Domain)
│       ├── Infrastructure/           # Data & AWS integration (→ Application, Domain)
│       └── Presentation/             # Minimal API endpoints & models (→ Application, Domain)
├── docs/                            # Documentation
├── docker-compose.yml               # SQL Server + API orchestration
└── README.md
```

### Dependency Flow
```
ApiHost → Presentation → Application → Domain
            ↓                ↓
      Infrastructure    Infrastructure
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
docker-compose logs -f auth-api                 # View logs
docker-compose down                             # Stop services

# Without Docker
cd src/ApiHost/AuthSamples.ApiHost
dotnet run                                      # Run API (localhost:5000)
```

### Database
```bash
# Create migration (MUST be run from Infrastructure directory)
cd src/Modules/Auth/AuthSamples.Modules.Auth.Infrastructure
dotnet ef migrations add MigrationName --startup-project ../../../ApiHost/AuthSamples.ApiHost

# Apply migrations
dotnet ef database update --startup-project ../../../ApiHost/AuthSamples.ApiHost

# Remove last migration (if not yet applied)
dotnet ef migrations remove --startup-project ../../../ApiHost/AuthSamples.ApiHost
```

**IMPORTANT**: Always include `--startup-project ../../../ApiHost/AuthSamples.ApiHost` when running EF Core commands, as the DbContext is in the Infrastructure project but the startup configuration is in the ApiHost project.

## Layer Details

### Domain Layer
**Purpose**: Pure business logic with no external dependencies

**Key Components**:
- **Entities**: User, UserIdentity, UserRole, Idp, LoginEvent, LogoutEvent, RegistrationFlowEvent, UserActivityLog
- **Value Objects**: Subject, EmailAddress, DeviceInfo (immutable, validated)
- **Enums**: RegistrationStatus, LoginResult, ActivityType
- **Repository Interfaces**: IUserRepository, IUserIdentityRepository, IUserRoleRepository, IIdpRepository, ILoginEventRepository, etc.
- **Domain Events**: UserRegisteredDomainEvent, UserLoggedInDomainEvent, etc.

**Patterns**:
- Aggregate roots with factory methods (User.Create, UserIdentity.Create, UserRole.Create, LoginEvent.CreateSuccess)
- Value objects with validation (EmailAddress.Create throws on invalid email, Subject.Create validates format)
- Rich domain model (User.Activate(), User.UpdateDisplayName(), UserIdentity.UpdateFromIdp(), UserIdentity.UpdateProfile())
- **Multi-IdP Design**: User (core identity) + UserIdentity (IdP-specific data) with 1-to-many relationship

### Application Layer
**Purpose**: Use case orchestration with CQRS

**Key Components**:
- **Commands**: RegisterUser, ConfirmRegistration, LoginUser, LogoutUser, RefreshToken, RevokeToken, SyncUser, UpdateUserProfile, UpdateRole, AddRole, CreateIdp, UpdateIdp
- **Queries**: GetUserProfile, GetUserLoginHistory, GetUserActivityLog, GetAllUsers, GetAllRoles, GetAllIdps
- **Handlers**: One handler per command/query
- **Validators**: FluentValidation (RegisterUserCommandValidator, UpdateUserProfileCommandValidator, CreateIdpCommandValidator, etc.)
- **Behaviors**: ValidationBehavior, LoggingBehavior, TransactionBehavior
- **DTOs**: RegisterUserDto, LoginUserDto, UserProfileDto, UserRoleDto, IdpDto, etc.

**Patterns**:
- CQRS with MediatR (commands modify, queries read)
- Pipeline behaviors for cross-cutting concerns
- Result pattern for operation outcomes
- Validator auto-registration via assembly scanning

### Infrastructure Layer
**Purpose**: External system integration (database, AWS)

**Key Components**:
- **DbContext**: AuthDbContext with 8 DbSets (Users, UserIdentities, UserRoles, Idps, LoginEvents, LogoutEvents, RegistrationFlowEvents, UserActivityLogs)
- **Entity Configurations**: Fluent API (UserConfiguration, UserIdentityConfiguration, UserRoleConfiguration, IdpConfiguration, LoginEventConfiguration, etc.)
- **Repositories**: UserRepository, UserIdentityRepository, UserRoleRepository, IdpRepository, LoginEventRepository, etc.
- **UnitOfWork**: Transaction coordinator
- **CognitoService**: AWS SDK wrapper (SignUpAsync, AuthenticateAsync, RefreshTokenAsync, GetUserAsync, GlobalSignOutAsync, etc.)
- **Settings**: CognitoSettings (UserPoolId, ClientId, ClientSecret, Region)

**Patterns**:
- Repository pattern with async/await
- Unit of Work for transaction management
- Value object conversions (Subject ↔ string, EmailAddress ↔ string)
- Owned entities (DeviceInfo inside LoginEvent)
- Auto-timestamps via IAuditableEntity in SaveChangesAsync
- **Multi-IdP Pattern**: UserIdentity queries using `(Issuer, Subject)` tuple for unique identification

### Presentation Layer
**Purpose**: HTTP endpoint definitions using Minimal APIs

**Key Components**:
- **Endpoints**: AuthEndpoints (6 public), UserEndpoints (5 authenticated), UserManagementEndpoints (2 Admin), RoleEndpoints (3 Admin), IdpEndpoints (3 Admin)
- **Endpoint Extensions**: MapAuthEndpoints, MapUserEndpoints, MapUserManagementEndpoints, MapRoleEndpoints, MapIdpEndpoints
- **Models**: Request/Response DTOs organized by feature (Auth, User, Role, Idp)
- **Helper Extensions**: ClaimsPrincipalExtensions (extract issuer/subject), HttpContextExtensions (get IP address)

**Patterns**:
- Minimal API with MapGroup for route organization
- Static endpoint methods for testability
- Endpoint → MediatR handler delegation
- Consistent API responses (ApiResponse<T>)
- Role-based authorization via RequireAuthorization(policy => policy.RequireRole("Admin"))
- Master endpoint registration via MapAuthModuleEndpoints()

### ApiHost Layer (AuthSamples.ApiHost)
**Purpose**: Infrastructure and composition root (top-level project, not module-specific)

**Location**: `src/ApiHost/AuthSamples.ApiHost/`

**Key Components**:
- **Configuration Modules**: AuthenticationConfiguration, SwaggerConfiguration, CorsConfiguration, HealthCheckConfiguration
- **Middleware**: ExceptionHandlingMiddleware, RequestLoggingMiddleware
- **Authorization**: UserRoleClaimsTransformation (adds database roles to JWT claims)
- **Health Checks**: CognitoHealthCheck
- **Program.cs**: Application startup and middleware pipeline configuration

**Patterns**:
- Extension methods for service registration (AddAuthAuthentication, AddAuthSwagger, etc.)
- JWT authentication with Cognito JWKS validation
- Global exception handling with error standardization
- EF Core migrations applied on startup
- Structured logging with Serilog
- **Module-agnostic**: Can host multiple modules in the future

## Database Schema

**Schema**: `auth` (renamed from `cognito` in Phase 1)

### Multi-IdP Architecture

The database supports multiple identity providers per user through table separation:
- **Users**: Core identity (DisplayName, IsActive, UserRoleId)
- **UserIdentities**: IdP-specific data (Subject, Email, FirstName, etc.)
- **Relationship**: One User can have many UserIdentities

### Tables

1. **Users** (Core Identity - Aggregate Root)
   - Columns: Id (GUID), UserRoleId (FK), DisplayName, IsActive, CreatedAt, UpdatedAt
   - Foreign Key: UserRoleId → UserRoles.Id (RESTRICT)
   - Navigation: Identities (ICollection<UserIdentity>)
   - **Purpose**: Stores core user information independent of IdP

2. **UserIdentities** (IdP-Specific Identity Data)
   - Columns: Id (GUID), UserId (FK), IdpId (FK), Issuer, Subject, Email, EmailVerified, FirstName, LastName, BirthDate, PhoneNumber, PhoneNumberVerified, LastSyncedAt, CreatedAt, UpdatedAt
   - Foreign Keys:
     - UserId → Users.Id (CASCADE DELETE)
     - IdpId → Idps.Id (RESTRICT)
   - Unique Constraint: (Issuer, Subject) - ensures each IdP subject is unique
   - **Purpose**: Stores IdP-specific user attributes that can vary per provider
   - **Lookup Pattern**: `GetByIssuerAndSubjectAsync(issuer, subject)` is the primary lookup method

3. **UserRoles** (Reference Data)
   - Columns: Id (GUID), RoleName, Description, CreatedAt, UpdatedAt
   - Unique Index: RoleName
   - Seeded Roles: Admin, User, SsoUser

4. **Idps** (Identity Providers Configuration)
   - Columns: Id (GUID), Name, Issuer (Unique), Authority, Description, LoginUrl, Enabled, AutoProvisionEnabled, ExpectedAudiences (JSON), AllowedAlgs (JSON), RequiredScopes (JSON), ClaimMapping (JSON), ClockSkewSeconds, CreatedAt, UpdatedAt
   - Unique Index: Issuer
   - Indexes: Enabled
   - Seeded IdP: IFX Cognito (`https://cognito-idp.ap-southeast-2.amazonaws.com/ap-southeast-2_adW7gmF5P`)

5. **LoginEvents**
   - Columns: Id, UserId, LoginTimestamp, Success, FailureReason, IpAddress, DeviceInfo (owned), CognitoSessionId, AccessToken, RefreshToken, TokenExpiresAt
   - Indexes: UserId, LoginTimestamp, (UserId, LoginTimestamp)
   - Foreign Key: UserId → Users.Id

6. **LogoutEvents**
   - Columns: Id, UserId, LogoutTimestamp, SessionDuration, IpAddress, Reason
   - Indexes: UserId, LogoutTimestamp
   - Foreign Key: UserId → Users.Id

7. **RegistrationFlowEvents**
   - Columns: Id, Email, Username, RegistrationInitiatedAt, RegistrationConfirmedAt, Status, ConfirmationCode, FailureReason, IpAddress, UserId
   - Indexes: Email, RegistrationInitiatedAt, Status
   - Foreign Key: UserId → Users.Id

8. **UserActivityLogs**
   - Columns: Id, UserId, ActivityType, Description, Timestamp, IpAddress, Metadata (JSON)
   - Indexes: UserId, Timestamp, (UserId, Timestamp)
   - Foreign Key: UserId → Users.Id

## Authentication Flow

### Registration
1. Client → POST /api/v1/auth/register
2. RegisterUserCommandHandler:
   - Creates user in Cognito (CognitoService.SignUpAsync)
   - Looks up default "User" role and IFX Cognito IdP from database
   - **Creates User entity** (DisplayName="FirstName LastName", IsActive=false, UserRoleId)
   - **Creates UserIdentity entity** (UserId, IdpId, Issuer, Subject from Cognito, Email, FirstName, LastName, etc.)
   - Creates RegistrationFlowEvent (Status=Initiated)
   - Saves to database
3. User receives email with confirmation code

**Key Change**: Now creates TWO entities - User (core) + UserIdentity (IdP-specific)

### Confirmation
1. Client → POST /api/v1/auth/confirm
2. ConfirmRegistrationCommandHandler:
   - Confirms user in Cognito
   - Updates User (IsActive=true)
   - Updates RegistrationFlowEvent (Status=Confirmed)

### Login
1. Client → POST /api/v1/auth/login
2. LoginUserCommandHandler:
   - Authenticates with Cognito (gets tokens)
   - **Extracts issuer from IdToken JWT** (iss claim)
   - Extracts subject from IdToken (sub claim)
   - **Looks up user** via `GetByIssuerAndSubjectAsync(issuer, subject)`
   - Syncs UserIdentity data from Cognito (UpdateFromIdp)
   - Updates User.DisplayName if name changed
   - Creates LoginEvent (with tokens, device info)
   - Creates UserActivityLog
   - Returns tokens + user profile

**Key Change**: Uses `(Issuer, Subject)` tuple for lookup instead of just Subject

### Logout
1. Client → POST /api/v1/auth/logout [Authorization: Bearer <token>]
2. LogoutUserCommandHandler:
   - **Extracts BOTH issuer and subject** from JWT claims
   - **Looks up user** via `GetByIssuerAndSubjectAsync(issuer, subject)`
   - Signs out from Cognito (GlobalSignOutAsync)
   - Creates LogoutEvent (calculates session duration from last login)
   - Creates UserActivityLog

**Key Change**: Requires both `iss` and `sub` claims in JWT

### Role-Based Authorization
- **JWT Claims Transformation**: UserRoleClaimsTransformation adds database role as ClaimTypes.Role claim to JWT principal
- **Process**: On each authenticated request, the middleware:
  1. **Extracts BOTH issuer ("iss") and subject ("sub")** from JWT claims
  2. Queries database via `GetByIssuerAndSubjectAsync(issuer, subject)`
  3. Loads user's UserRole
  4. Adds role claim to ClaimsPrincipal
- **Usage**: Enables standard ASP.NET Core `[Authorize(Roles = "Admin")]` attribute

**Key Change**: Multi-IdP safe - uses `(Issuer, Subject)` for unique user identification

## Configuration

### Required Settings (appsettings.json or .env)

```json
{
  "ConnectionStrings": {
    "AuthDatabase": "Server=localhost,1433;Database=AuthSamplesDb;User Id=sa;Password=YourStrong@Passw0rd;TrustServerCertificate=True"
  },
  "CognitoSettings": {
    "UserPoolId": "ap-southeast-2_adW7gmF5P",
    "ClientId": "XXXXXXXXXXXXXXXXXXXXXXXXXX",
    "ClientSecret": "XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX",
    "Region": "ap-southeast-2"
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
- `POST /api/v1/auth/refresh` - Refresh access token using refresh token
- `POST /api/v1/auth/revoke` - Revoke all tokens for current user
- `GET /api/v1/user/profile` - Get current user profile
- `PUT /api/v1/user/profile` - Update current user profile (partial updates)
- `GET /api/v1/user/login-history` - Get paginated login history
- `GET /api/v1/user/activity-log` - Get paginated activity log
- `POST /api/v1/user/sync` - Sync user data from Cognito

### Admin-Only Endpoints (require Admin role)
- `GET /api/v1/usermanagement/users` - Get all users (paginated)
- `PUT /api/v1/usermanagement/users/{userId}` - Update any user profile (uses internal GUID)
- `GET /api/v1/role` - Get all roles
- `PUT /api/v1/role/{roleId}` - Update role name and description
- `POST /api/v1/role` - Add new role
- `GET /api/v1/idp` - Get all Identity Providers
- `POST /api/v1/idp` - Create new Identity Provider
- `PUT /api/v1/idp/{idpId}` - Update existing Identity Provider

### Health Check Endpoints (public)
- `GET /health` - Detailed health check with JSON response (all checks)
- `GET /health/ready` - Simple readiness probe (returns status text)

### Swagger UI
Available at `http://localhost:5000/swagger` with JWT Bearer authentication support.

## Key Design Decisions

### CQRS with MediatR
- **Commands**: Modify state (Register, Login, Logout) - wrapped in transactions via TransactionBehavior
- **Queries**: Read data (GetUserProfile, GetLoginHistory) - use AsNoTracking() for performance
- **Separation**: Commands publish domain events, queries are read-only projections

### Multi-IdP Support (Updated January 2026)
- **Architecture**: User (core identity) + UserIdentity (IdP-specific data)
- **Unique Identification**: `(Issuer, Subject)` tuple ensures each IdP identity is unique
- **Primary Lookup**: `GetByIssuerAndSubjectAsync(issuer, subject)` replaces Subject-only lookups
- **Scalability**: Users can link multiple IdP accounts (e.g., Google SSO + Cognito)
- **Current IdPs**: IFX Cognito (`https://cognito-idp.ap-southeast-2.amazonaws.com/ap-southeast-2_adW7gmF5P`)
- **Future Ready**: Add new IdPs by seeding Idps table, no code changes required

### Value Objects
- **Subject**: IdP-assigned unique identifier (validates format, immutable)
- **EmailAddress**: Validates email with regex (immutable)
- **DeviceInfo**: Parses User-Agent string (browser, OS, device type, isBot)

### Audit Trail Strategy
- **LoginEvent**: Every login attempt (success/failure) with IP, device, tokens
- **LogoutEvent**: Session duration calculated from LoginTimestamp
- **RegistrationFlowEvent**: Track registration lifecycle (Initiated → Confirmed/Failed/Expired)
- **UserActivityLog**: General activity tracking (Registration, Login, Logout, ProfileUpdate)

### User Lookup Pattern
- **Controllers**: Extract BOTH "iss" (issuer) and "sub" (subject) from JWT claims
- **Commands/Queries**: Accept `(Issuer, Subject)` parameters for authenticated endpoints
- **Handlers**: Look up User via `GetByIssuerAndSubjectAsync(issuer, subject)` to get User + UserIdentity
- **Repositories**: Work with internal UserId (Guid) for foreign keys
- **Primary Lookup Methods**:
  - `GetByIssuerAndSubjectAsync(issuer, subject)` - Primary lookup using IdP issuer + subject (most common)
  - `GetByEmailAndIdpAsync(email, idpId)` - Lookup by email scoped to specific IdP (for registration, confirmation, refresh token)
- **Examples**:
  ```csharp
  // Authenticated endpoints (has JWT with iss + sub claims)
  var user = await _unitOfWork.Users.GetByIssuerAndSubjectAsync(issuer, subject);

  // Registration/Confirmation/RefreshToken (has email + knows IdP)
  var ifxCognitoIdp = await _unitOfWork.Idps.GetByIssuerAsync(ifxCognitoIssuer);
  var user = await _unitOfWork.Users.GetByEmailAndIdpAsync(email, ifxCognitoIdp.Id);
  ```

### User Role Management
- **Default Roles**: Admin, User, SsoUser (seeded via migrations)
- **Role Assignment**: All new users get "User" role by default during registration
- **Role Enforcement**: Claims transformation adds role from database to JWT on every request
- **Admin Access**: Only users with "Admin" role can access UserManagementController and RoleController
- **Profile Updates**:
  - Users can update their own profile via `PUT /api/v1/user/profile`
  - Admins can update any user's profile via `PUT /api/v1/usermanagement/users/{userId}` (uses internal GUID)
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
- **File**: `logs/auth-api-YYYYMMDD.log` (rolling daily)

Log levels:
- **Information**: HTTP requests (method, path, status code, duration)
- **Warning**: Failed auth, validation errors
- **Error**: Exceptions, system errors
- **Fatal**: Application termination

## Health Checks

The application implements comprehensive health checks for monitoring system health and dependencies:

### Configured Health Checks
1. **SQL Server Health Check**
   - Verifies database connectivity
   - Executes `SELECT 1` query
   - Reports status: Healthy/Unhealthy
   - Tags: `database`, `sqlserver`

2. **AWS Cognito Health Check**
   - Verifies AWS Cognito User Pool accessibility
   - Calls `DescribeUserPool` API
   - Validates User Pool configuration
   - Reports User Pool name and creation date
   - Tags: `aws`, `cognito`, `authentication`
   - Status levels:
     - **Healthy**: Cognito is accessible and User Pool is active
     - **Degraded**: Cognito is accessible but has permission issues
     - **Unhealthy**: Cognito is not accessible or User Pool not found

### Health Check Endpoints
- **GET /health** - Detailed JSON response with individual check results, durations, and metadata
- **GET /health/ready** - Simple text response (Healthy/Degraded/Unhealthy) suitable for Kubernetes readiness probes

### Health Check Implementation
Located in `API/HealthChecks/CognitoHealthCheck.cs`. Custom health checks implement `IHealthCheck` interface and are registered in Program.cs via `AddHealthChecks()` builder method.

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
3. Add DbSet to AuthDbContext
4. Create repository interface in Domain/Interfaces/Repositories and implementation in Infrastructure/Persistence/Repositories
5. Add repository to IUnitOfWork interface and UnitOfWork implementation
6. Register repository in Infrastructure DependencyInjection.cs
7. Create DTO in Application/DTOs/EntityNameDto.cs
8. **CRITICAL**: Add AutoMapper mapping in Application/Mappings/MappingProfile.cs: `CreateMap<EntityName, EntityNameDto>();`
9. Create migration: `dotnet ef migrations add AddEntityName --startup-project ../AuthSamples.Modules.Auth.API`

**IMPORTANT**: Step 8 is mandatory. Forgetting to add the AutoMapper mapping will cause runtime errors when handlers try to map entities to DTOs.

### Working with User + UserIdentity (Multi-IdP Pattern)

**Looking up a user from JWT claims (Controllers)**:
```csharp
// Extract BOTH issuer and subject from JWT
var subject = User.FindFirst("sub")?.Value;
var issuer = User.FindFirst("iss")?.Value;

if (string.IsNullOrEmpty(issuer) || string.IsNullOrEmpty(subject))
    return Unauthorized(...);

// Pass both to command/query
var command = new SomeCommand(issuer, subject, ...);
```

**Looking up a user in handlers**:
```csharp
// Get user with UserIdentity loaded
var user = await _unitOfWork.Users.GetByIssuerAndSubjectAsync(request.Issuer, request.Subject, cancellationToken);
if (user == null)
    return Result.Failure("User not found");

// Access UserIdentity data
var identity = user.Identities.FirstOrDefault(i => i.Issuer == request.Issuer && i.Subject.Value == request.Subject);
var email = identity.Email.Value;
var displayName = user.DisplayName; // From User entity
```

**Updating user profile**:
```csharp
// Update UserIdentity (IdP-specific data)
identity.UpdateProfile(firstName, lastName, phoneNumber);

// Update User DisplayName if name changed
if (firstName != null || lastName != null)
{
    var newDisplayName = $"{identity.FirstName} {identity.LastName}";
    user.UpdateDisplayName(newDisplayName);
}

await _unitOfWork.UserIdentities.UpdateAsync(identity, cancellationToken);
await _unitOfWork.Users.UpdateAsync(user, cancellationToken);
```

**Creating new user (Registration)**:
```csharp
// 1. Get IdP
var idp = await _unitOfWork.Idps.GetByIssuerAsync("https://cognito-idp...", cancellationToken);

// 2. Create User (core identity)
var user = User.Create(userRoleId, displayName: $"{firstName} {lastName}", isActive: false);
await _unitOfWork.Users.AddAsync(user, cancellationToken);

// 3. Create UserIdentity (IdP-specific data)
var userIdentity = UserIdentity.Create(
    userId: user.Id,
    idpId: idp.Id,
    issuer: "https://cognito-idp...",
    subject: Subject.Create(cognitoSubject),
    email: EmailAddress.Create(email),
    firstName, lastName, birthDate, phoneNumber,
    emailVerified: false, phoneNumberVerified: false);

await _unitOfWork.UserIdentities.AddAsync(userIdentity, cancellationToken);
await _unitOfWork.SaveChangesAsync(cancellationToken);
```

### Seed Reference Data in Migrations
When adding reference data (roles, statuses, etc.) that must exist before application code runs:
1. Create migration as normal
2. Modify the generated migration file's Up() method:
   ```csharp
   var roleId = Guid.NewGuid();
   var now = DateTime.UtcNow;

   migrationBuilder.InsertData(
       schema: "auth",
       table: "TableName",
       columns: new[] { "Id", "Column1", "CreatedAt", "UpdatedAt" },
       values: new object[] { roleId, "Value1", now, now });
   ```
3. Add corresponding Down() method:
   ```csharp
   migrationBuilder.DeleteData(
       schema: "auth",
       table: "TableName",
       keyColumn: "Column1",
       keyValue: "Value1");
   ```

## Testing Locally

**IMPORTANT**: The Docker SQL Server container is configured to expose port **11433** on the host (mapped to 1433 inside the container). When running locally without Docker, update `appsettings.Development.json` connection string to use port **11433**:

```json
"AuthDatabase": "Server=localhost,11433;Database=AuthSamplesDb;User Id=sa;Password=YourStrong@Pass123;TrustServerCertificate=True;MultipleActiveResultSets=true"
```

```bash
# 1. Start SQL Server
docker-compose up sqlserver -d

# 2. Apply migrations (from Infrastructure directory)
cd src/Modules/Auth/AuthSamples.Modules.Auth.Infrastructure
dotnet ef database update --startup-project ../../../ApiHost/AuthSamples.ApiHost

# 3. Run API
cd ../../../ApiHost/AuthSamples.ApiHost
dotnet run

# 4. Test with curl
curl -X POST http://localhost:5000/api/v1/auth/register \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","password":"Test@12345","username":"testuser","firstName":"Test","lastName":"User","birthDate":"1990-01-01","phoneNumber":"+1234567890"}'
```

## Troubleshooting

### Build Errors
- **NU1603 Warning**: AWS SDK version mismatch - safe to ignore, uses newer compatible version
- **Configuration binding errors**: Ensure `Microsoft.Extensions.Configuration.Binder` package is installed

### Runtime Errors
- **Database connection failed**: Check SQL Server is running and connection string is correct (use port 11433 for local Docker SQL Server)
- **Cognito errors**: Verify UserPoolId, ClientId, ClientSecret, Region in appsettings.json or .env
- **JWT validation failed**: Ensure Cognito Authority URL is correct
- **AutoMapper configuration errors**: Ensure all entities have corresponding DTOs and mappings in MappingProfile.cs

### Migration Errors
- **Startup project not specified**: Always use `--startup-project ../AuthSamples.Modules.Auth.API`
- **DbContext not found**: Ensure you're in the Infrastructure project directory

## Completed Features

- [x] **Multi-IdP Architecture** (January 2026) - User + UserIdentity table separation
- [x] **Issuer+Subject Lookup Pattern** - All handlers use `(Issuer, Subject)` tuple
- [x] **IdP-Scoped Email Lookup** - `GetByEmailAndIdpAsync` prevents duplicate emails across IdPs
- [x] Module renamed from Cognito to Auth
- [x] User role system (Admin, User, SsoUser)
- [x] Role-based authorization with claims transformation
- [x] User management endpoints (Admin-only)
- [x] Role management endpoints (Admin-only)
- [x] User profile update endpoints (self-service and admin)
- [x] Partial update support for user profiles
- [x] Multi-IDP support with Idps table
- [x] Identity Provider management endpoints (Admin-only)
- [x] OAuth 2.0 refresh token endpoint
- [x] Token revocation endpoint
- [x] Health checks (SQL Server, AWS Cognito)

## Future Enhancements

Potential improvements:
- [ ] **Additional IdP Integration** (Google SSO, Azure AD, Okta, Auth0)
- [ ] **Account Linking UI** - Allow users to link multiple IdP accounts
- [ ] Add unit and integration tests (xUnit, FluentAssertions, Testcontainers)
- [ ] Add password reset flow (forgot password)
- [ ] Implement email change functionality
- [ ] Add account deletion (soft delete)
- [ ] Add role assignment endpoint (change user's role)
- [ ] Implement rate limiting (AspNetCoreRateLimit)
- [ ] Add API versioning (Asp.Versioning.Mvc)
- [ ] Add distributed caching (Redis) for role lookups
- [ ] Implement event sourcing for audit trail
- [ ] Add OpenTelemetry for observability
- [ ] Add user search and filtering in admin endpoints
- [ ] Add GetIdpById query endpoint
- [ ] Add health check UI dashboard (AspNetCore.HealthChecks.UI)

## Migration Documentation

For detailed information about the multi-IdP architecture migration:
- **[Multi-IdP Migration Summary](docs/MULTI_IDP_MIGRATION_SUMMARY.md)** - Complete 3-phase migration documentation
  - Phase 1: Module rename (Cognito → Auth)
  - Phase 2: Table restructuring (User split)
  - Phase 3: Handler updates (Issuer+Subject pattern)
  - Rollback strategies
  - Testing checklist
