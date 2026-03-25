# Plan: Refactor Auth Module into Internal Subdomains

**Date:** 2026-03-16
**Branch:** `feature/auth-subdomain-refactor`
**Status:** Implemented
**Scope:** Internal reorganization only — no new modules, no behavior changes.

---

## Goal

Reorganize the Auth module's internal structure into three subdomains:

- **Users** — local user entity, profile, status, activity
- **Identity** — authentication, tokens, IdP integration, email verification
- **Authorization** — roles, permissions, role assignments

The module boundary (single module, single DI registration, single DB context) remains unchanged.

---

## Subdomain Classification

### Domain Layer

| Current Path | New Path | Subdomain |
|---|---|---|
| `Common/BaseEntity.cs` | `Common/BaseEntity.cs` | *(shared — no move)* |
| `Common/IAuditableEntity.cs` | `Common/IAuditableEntity.cs` | *(shared — no move)* |
| `Entities/User.cs` | `Users/User.cs` | Users |
| `Entities/UserActivityLog.cs` | `Users/UserActivityLog.cs` | Users |
| `Entities/UserRole.cs` | `Authorization/UserRole.cs` | Authorization |
| `Entities/UserIdentity.cs` | `Identity/UserIdentity.cs` | Identity |
| `Entities/EmailVerificationToken.cs` | `Identity/EmailVerificationToken.cs` | Identity |
| `Entities/Idp.cs` | `Identity/Idp.cs` | Identity |
| `Entities/LoginEvent.cs` | `Identity/LoginEvent.cs` | Identity |
| `Entities/LogoutEvent.cs` | `Identity/LogoutEvent.cs` | Identity |
| `Entities/RegistrationFlowEvent.cs` | `Identity/RegistrationFlowEvent.cs` | Identity |
| `Enums/ActivityType.cs` | `Users/ActivityType.cs` | Users |
| `Enums/RegistrationStatus.cs` | `Users/RegistrationStatus.cs` | Users |
| `Enums/IdpType.cs` | `Identity/IdpType.cs` | Identity |
| `Enums/LoginResult.cs` | `Identity/LoginResult.cs` | Identity |
| `Events/UserRegisteredDomainEvent.cs` | `Users/Events/UserRegisteredDomainEvent.cs` | Users |
| `Events/RegistrationConfirmedDomainEvent.cs` | `Users/Events/RegistrationConfirmedDomainEvent.cs` | Users |
| `Events/UserSyncedDomainEvent.cs` | `Users/Events/UserSyncedDomainEvent.cs` | Users |
| `Events/UserLoggedInDomainEvent.cs` | `Identity/Events/UserLoggedInDomainEvent.cs` | Identity |
| `Events/UserLoggedOutDomainEvent.cs` | `Identity/Events/UserLoggedOutDomainEvent.cs` | Identity |
| `Interfaces/Repositories/IUserRepository.cs` | `Users/IUserRepository.cs` | Users |
| `Interfaces/Repositories/IUserActivityLogRepository.cs` | `Users/IUserActivityLogRepository.cs` | Users |
| `Interfaces/Repositories/IUserIdentityRepository.cs` | `Identity/IUserIdentityRepository.cs` | Identity |
| `Interfaces/Repositories/IEmailVerificationTokenRepository.cs` | `Identity/IEmailVerificationTokenRepository.cs` | Identity |
| `Interfaces/Repositories/IIdpRepository.cs` | `Identity/IIdpRepository.cs` | Identity |
| `Interfaces/Repositories/ILoginEventRepository.cs` | `Identity/ILoginEventRepository.cs` | Identity |
| `Interfaces/Repositories/ILogoutEventRepository.cs` | `Identity/ILogoutEventRepository.cs` | Identity |
| `Interfaces/Repositories/IRegistrationFlowEventRepository.cs` | `Identity/IRegistrationFlowEventRepository.cs` | Identity |
| `Interfaces/Repositories/IUserRoleRepository.cs` | `Authorization/IUserRoleRepository.cs` | Authorization |
| `ValueObjects/EmailAddress.cs` | `Users/EmailAddress.cs` | Users |
| `ValueObjects/DeviceInfo.cs` | `Identity/DeviceInfo.cs` | Identity |
| `ValueObjects/Subject.cs` | `Identity/Subject.cs` | Identity |

**Domain namespace changes:**
```
IFX.Modules.Auth.Domain.Entities     → IFX.Modules.Auth.Domain.Users
                                       IFX.Modules.Auth.Domain.Identity
                                       IFX.Modules.Auth.Domain.Authorization
IFX.Modules.Auth.Domain.Enums        → IFX.Modules.Auth.Domain.Users
                                       IFX.Modules.Auth.Domain.Identity
IFX.Modules.Auth.Domain.Events       → IFX.Modules.Auth.Domain.Users.Events
                                       IFX.Modules.Auth.Domain.Identity.Events
IFX.Modules.Auth.Domain.Interfaces.Repositories → IFX.Modules.Auth.Domain.Users
                                                   IFX.Modules.Auth.Domain.Identity
                                                   IFX.Modules.Auth.Domain.Authorization
IFX.Modules.Auth.Domain.ValueObjects → IFX.Modules.Auth.Domain.Users
                                       IFX.Modules.Auth.Domain.Identity
```

---

### Application Layer

**Behaviors** (cross-cutting, no move):
`LoggingBehavior`, `TransactionBehavior`, `ValidationBehavior` stay in `Behaviors/`.

**Common** (cross-cutting, no move):
`Common/Result.cs`, `Mappings/MappingProfile.cs`, `IUnitOfWork.cs`, `DependencyInjection.cs` stay in place.

**Commands:**

| Current Path | New Path | Subdomain |
|---|---|---|
| `Commands/UpdateUserProfile/` | `Users/Commands/UpdateUserProfile/` | Users |
| `Commands/RegisterUser/` | `Identity/Commands/RegisterUser/` | Identity |
| `Commands/ConfirmRegistration/` | `Identity/Commands/ConfirmRegistration/` | Identity |
| `Commands/SendEmailVerification/` | `Identity/Commands/SendEmailVerification/` | Identity |
| `Commands/ResendEmailVerification/` | `Identity/Commands/ResendEmailVerification/` | Identity |
| `Commands/VerifyEmail/` | `Identity/Commands/VerifyEmail/` | Identity |
| `Commands/LoginUser/` | `Identity/Commands/LoginUser/` | Identity |
| `Commands/LogoutUser/` | `Identity/Commands/LogoutUser/` | Identity |
| `Commands/RefreshToken/` | `Identity/Commands/RefreshToken/` | Identity |
| `Commands/RevokeToken/` | `Identity/Commands/RevokeToken/` | Identity |
| `Commands/SyncUser/` | `Identity/Commands/SyncUser/` | Identity |
| `Commands/ProvisionSsoUser/` | `Identity/Commands/ProvisionSsoUser/` | Identity |
| `Commands/CreateIdp/` | `Identity/Commands/CreateIdp/` | Identity |
| `Commands/UpdateIdp/` | `Identity/Commands/UpdateIdp/` | Identity |
| `Commands/AddRole/` | `Authorization/Commands/AddRole/` | Authorization |
| `Commands/UpdateRole/` | `Authorization/Commands/UpdateRole/` | Authorization |

**Queries:**

| Current Path | New Path | Subdomain |
|---|---|---|
| `Queries/GetUserProfile/` | `Users/Queries/GetUserProfile/` | Users |
| `Queries/GetAllUsers/` | `Users/Queries/GetAllUsers/` | Users |
| `Queries/GetUserActivityLog/` | `Users/Queries/GetUserActivityLog/` | Users |
| `Queries/GetUserLoginHistory/` | `Users/Queries/GetUserLoginHistory/` | Users |
| `Queries/GetAllIdps/` | `Identity/Queries/GetAllIdps/` | Identity |
| `Queries/GetOrProvisionUser/` | `Identity/Queries/GetOrProvisionUser/` | Identity |
| `Queries/GetAllRoles/` | `Authorization/Queries/GetAllRoles/` | Authorization |

**DTOs:**

| Current Path | New Path | Subdomain |
|---|---|---|
| `DTOs/UserProfileDto.cs` | `Users/DTOs/UserProfileDto.cs` | Users |
| `DTOs/UserActivityDto.cs` | `Users/DTOs/UserActivityDto.cs` | Users |
| `DTOs/RegisterUserDto.cs` | `Identity/DTOs/RegisterUserDto.cs` | Identity |
| `DTOs/ConfirmRegistrationDto.cs` | `Identity/DTOs/ConfirmRegistrationDto.cs` | Identity |
| `DTOs/EmailVerificationDto.cs` | `Identity/DTOs/EmailVerificationDto.cs` | Identity |
| `DTOs/LoginUserDto.cs` | `Identity/DTOs/LoginUserDto.cs` | Identity |
| `DTOs/LoginEventDto.cs` | `Identity/DTOs/LoginEventDto.cs` | Identity |
| `DTOs/UserAuthResult.cs` | `Identity/DTOs/UserAuthResult.cs` | Identity |
| `DTOs/RefreshTokenResponse.cs` | `Identity/DTOs/RefreshTokenResponse.cs` | Identity |
| `DTOs/ProvisionSsoUserResponse.cs` | `Identity/DTOs/ProvisionSsoUserResponse.cs` | Identity |
| `DTOs/IdpDto.cs` | `Identity/DTOs/IdpDto.cs` | Identity |
| `DTOs/UserRoleDto.cs` | `Authorization/DTOs/UserRoleDto.cs` | Authorization |

**Interfaces:**

| Current Path | New Path | Subdomain |
|---|---|---|
| `Interfaces/IEmailVerificationService.cs` | `Identity/Interfaces/IEmailVerificationService.cs` | Identity |
| `Interfaces/IEmailVerificationCleanupService.cs` | `Identity/Interfaces/IEmailVerificationCleanupService.cs` | Identity |
| `Interfaces/ICognitoService.cs` | `Identity/Interfaces/ICognitoService.cs` | Identity |
| `Interfaces/IOidcAuthService.cs` | `Identity/Interfaces/IOidcAuthService.cs` | Identity |
| `Interfaces/IOidcDiscoveryService.cs` | `Identity/Interfaces/IOidcDiscoveryService.cs` | Identity |
| `Interfaces/IIdpCacheInvalidator.cs` | `Identity/Interfaces/IIdpCacheInvalidator.cs` | Identity |
| `Interfaces/IUnitOfWork.cs` | `Interfaces/IUnitOfWork.cs` | *(shared — no move)* |

**Application namespace changes:**
```
IFX.Modules.Auth.Application.Commands.UpdateUserProfile     → IFX.Modules.Auth.Application.Users.Commands.UpdateUserProfile
IFX.Modules.Auth.Application.Commands.LoginUser             → IFX.Modules.Auth.Application.Identity.Commands.LoginUser
IFX.Modules.Auth.Application.Commands.AddRole              → IFX.Modules.Auth.Application.Authorization.Commands.AddRole
IFX.Modules.Auth.Application.Queries.GetUserProfile        → IFX.Modules.Auth.Application.Users.Queries.GetUserProfile
IFX.Modules.Auth.Application.Queries.GetAllIdps            → IFX.Modules.Auth.Application.Identity.Queries.GetAllIdps
IFX.Modules.Auth.Application.Queries.GetAllRoles           → IFX.Modules.Auth.Application.Authorization.Queries.GetAllRoles
IFX.Modules.Auth.Application.DTOs                          → IFX.Modules.Auth.Application.{Users|Identity|Authorization}.DTOs
IFX.Modules.Auth.Application.Interfaces                    → IFX.Modules.Auth.Application.Identity.Interfaces
                                                              IFX.Modules.Auth.Application.Interfaces (IUnitOfWork stays)
```

---

### Infrastructure Layer

**Users:**

| Current Path | New Path |
|---|---|
| `Persistence/Repositories/UserRepository.cs` | `Users/Repositories/UserRepository.cs` |
| `Persistence/Repositories/UserActivityLogRepository.cs` | `Users/Repositories/UserActivityLogRepository.cs` |
| `Persistence/Repositories/EmailVerificationTokenRepository.cs` | `Users/Repositories/EmailVerificationTokenRepository.cs` |
| `Persistence/Configurations/UserConfiguration.cs` | `Users/Configurations/UserConfiguration.cs` |
| `Persistence/Configurations/UserActivityLogConfiguration.cs` | `Users/Configurations/UserActivityLogConfiguration.cs` |
| `Persistence/Configurations/EmailVerificationTokenConfiguration.cs` | `Users/Configurations/EmailVerificationTokenConfiguration.cs` |
| `Services/EmailVerificationService.cs` | `Users/Services/EmailVerificationService.cs` |
| `Services/EmailVerificationCleanupService.cs` | `Users/Services/EmailVerificationCleanupService.cs` |

**Identity:**

| Current Path | New Path |
|---|---|
| `Configuration/CognitoSettings.cs` | `Identity/Configuration/CognitoSettings.cs` |
| `Configuration/CognitoOidcSettings.cs` | `Identity/Configuration/CognitoOidcSettings.cs` |
| `Services/CognitoService.cs` | `Identity/Services/CognitoService.cs` |
| `Services/CognitoOidcService.cs` | `Identity/Services/CognitoOidcService.cs` |
| `Services/OidcDiscoveryService.cs` | `Identity/Services/OidcDiscoveryService.cs` |
| `Persistence/Repositories/UserIdentityRepository.cs` | `Identity/Repositories/UserIdentityRepository.cs` |
| `Persistence/Repositories/LoginEventRepository.cs` | `Identity/Repositories/LoginEventRepository.cs` |
| `Persistence/Repositories/LogoutEventRepository.cs` | `Identity/Repositories/LogoutEventRepository.cs` |
| `Persistence/Repositories/RegistrationFlowEventRepository.cs` | `Identity/Repositories/RegistrationFlowEventRepository.cs` |
| `Persistence/Repositories/IdpRepository.cs` | `Identity/Repositories/IdpRepository.cs` |
| `Persistence/Configurations/UserIdentityConfiguration.cs` | `Identity/Configurations/UserIdentityConfiguration.cs` |
| `Persistence/Configurations/LoginEventConfiguration.cs` | `Identity/Configurations/LoginEventConfiguration.cs` |
| `Persistence/Configurations/LogoutEventConfiguration.cs` | `Identity/Configurations/LogoutEventConfiguration.cs` |
| `Persistence/Configurations/RegistrationFlowEventConfiguration.cs` | `Identity/Configurations/RegistrationFlowEventConfiguration.cs` |
| `Persistence/Configurations/IdpConfiguration.cs` | `Identity/Configurations/IdpConfiguration.cs` |

**Authorization:**

| Current Path | New Path |
|---|---|
| `Persistence/Repositories/UserRoleRepository.cs` | `Authorization/Repositories/UserRoleRepository.cs` |
| `Persistence/Configurations/UserRoleConfiguration.cs` | `Authorization/Configurations/UserRoleConfiguration.cs` |

**Shared (no move):**
- `Persistence/IfxDbContext.cs`
- `Persistence/UnitOfWork.cs`
- `Persistence/Migrations/` (all 29 migration files — never move migrations)
- `DependencyInjection.cs`

**Infrastructure namespace changes:**
```
IFX.Modules.Auth.Infrastructure.Configuration              → IFX.Modules.Auth.Infrastructure.Identity.Configuration
IFX.Modules.Auth.Infrastructure.Services                   → IFX.Modules.Auth.Infrastructure.Users.Services
                                                              IFX.Modules.Auth.Infrastructure.Identity.Services
IFX.Modules.Auth.Infrastructure.Persistence.Repositories  → IFX.Modules.Auth.Infrastructure.Users.Repositories
                                                              IFX.Modules.Auth.Infrastructure.Identity.Repositories
                                                              IFX.Modules.Auth.Infrastructure.Authorization.Repositories
IFX.Modules.Auth.Infrastructure.Persistence.Configurations → IFX.Modules.Auth.Infrastructure.Users.Configurations
                                                              IFX.Modules.Auth.Infrastructure.Identity.Configurations
                                                              IFX.Modules.Auth.Infrastructure.Authorization.Configurations
```

---

### Presentation Layer

**Users:**

| Current Path | New Path |
|---|---|
| `Endpoints/User/UserEndpoints.cs` | `Users/Endpoints/UserEndpoints.cs` |
| `Endpoints/User/UserEndpointExtensions.cs` | `Users/Endpoints/UserEndpointExtensions.cs` |
| `Endpoints/UserManagement/UserManagementEndpoints.cs` | `Users/Endpoints/UserManagementEndpoints.cs` |
| `Endpoints/UserManagement/UserManagementEndpointExtensions.cs` | `Users/Endpoints/UserManagementEndpointExtensions.cs` |
| `Endpoints/EmailVerification/EmailVerificationEndpoints.cs` | `Users/Endpoints/EmailVerificationEndpoints.cs` |
| `Endpoints/EmailVerification/EmailVerificationEndpointExtensions.cs` | `Users/Endpoints/EmailVerificationEndpointExtensions.cs` |
| `Models/Requests/User/UpdateUserProfileRequest.cs` | `Users/Requests/UpdateUserProfileRequest.cs` |
| `Models/Requests/EmailVerification/VerifyEmailRequest.cs` | `Users/Requests/VerifyEmailRequest.cs` |

**Identity:**

| Current Path | New Path |
|---|---|
| `Endpoints/Auth/AuthEndpoints.cs` | `Identity/Endpoints/AuthEndpoints.cs` |
| `Endpoints/Auth/AuthEndpointExtensions.cs` | `Identity/Endpoints/AuthEndpointExtensions.cs` |
| `Endpoints/OAuth/OAuthEndpoints.cs` | `Identity/Endpoints/OAuthEndpoints.cs` |
| `Endpoints/OAuth/OAuthEndpointExtensions.cs` | `Identity/Endpoints/OAuthEndpointExtensions.cs` |
| `Endpoints/Idp/IdpEndpoints.cs` | `Identity/Endpoints/IdpEndpoints.cs` |
| `Endpoints/Idp/IdpEndpointExtensions.cs` | `Identity/Endpoints/IdpEndpointExtensions.cs` |
| `Models/Requests/Auth/ConfirmRegistrationRequest.cs` | `Identity/Requests/ConfirmRegistrationRequest.cs` |
| `Models/Requests/Auth/LoginRequest.cs` | `Identity/Requests/LoginRequest.cs` |
| `Models/Requests/Auth/RefreshTokenRequest.cs` | `Identity/Requests/RefreshTokenRequest.cs` |
| `Models/Requests/Auth/RegisterRequest.cs` | `Identity/Requests/RegisterRequest.cs` |
| `Models/Requests/Auth/RevokeTokenRequest.cs` | `Identity/Requests/RevokeTokenRequest.cs` |
| `Models/Requests/Idp/CreateIdpRequest.cs` | `Identity/Requests/CreateIdpRequest.cs` |
| `Models/Requests/Idp/UpdateIdpRequest.cs` | `Identity/Requests/UpdateIdpRequest.cs` |

**Authorization:**

| Current Path | New Path |
|---|---|
| `Endpoints/Role/RoleEndpoints.cs` | `Authorization/Endpoints/RoleEndpoints.cs` |
| `Endpoints/Role/RoleEndpointExtensions.cs` | `Authorization/Endpoints/RoleEndpointExtensions.cs` |
| `Models/Requests/Role/AddRoleRequest.cs` | `Authorization/Requests/AddRoleRequest.cs` |
| `Models/Requests/Role/UpdateRoleRequest.cs` | `Authorization/Requests/UpdateRoleRequest.cs` |

**Shared (no move):**
- `Extensions/ClaimsPrincipalExtensions.cs`
- `Extensions/HttpContextExtensions.cs`
- `Models/Responses/ApiResponse.cs`

---

## Target Folder Structure

```
Auth.Domain/
  Common/
    BaseEntity.cs
    IAuditableEntity.cs
  Users/
    User.cs
    UserActivityLog.cs
    ActivityType.cs
    RegistrationStatus.cs
    EmailAddress.cs
    IUserRepository.cs
    IUserActivityLogRepository.cs
    Events/
      UserRegisteredDomainEvent.cs
      RegistrationConfirmedDomainEvent.cs
      UserSyncedDomainEvent.cs
  Identity/
    UserIdentity.cs
    EmailVerificationToken.cs
    Idp.cs
    LoginEvent.cs
    LogoutEvent.cs
    RegistrationFlowEvent.cs
    IdpType.cs
    LoginResult.cs
    DeviceInfo.cs
    Subject.cs
    IUserIdentityRepository.cs
    IEmailVerificationTokenRepository.cs
    IIdpRepository.cs
    ILoginEventRepository.cs
    ILogoutEventRepository.cs
    IRegistrationFlowEventRepository.cs
    Events/
      UserLoggedInDomainEvent.cs
      UserLoggedOutDomainEvent.cs
  Authorization/
    UserRole.cs
    IUserRoleRepository.cs

Auth.Application/
  Behaviors/                         ← no move
  Common/                            ← no move
  Interfaces/
    IUnitOfWork.cs                   ← no move
  Mappings/                          ← no move
  Users/
    Commands/
      UpdateUserProfile/
    Queries/
      GetUserProfile/
      GetAllUsers/
      GetUserActivityLog/
      GetUserLoginHistory/
    DTOs/
      UserProfileDto.cs
      UserActivityDto.cs
  Identity/
    Commands/
      RegisterUser/
      ConfirmRegistration/
      SendEmailVerification/
      ResendEmailVerification/
      VerifyEmail/
      LoginUser/
      LogoutUser/
      RefreshToken/
      RevokeToken/
      SyncUser/
      ProvisionSsoUser/
      CreateIdp/
      UpdateIdp/
    Queries/
      GetAllIdps/
      GetOrProvisionUser/
    DTOs/
      RegisterUserDto.cs
      ConfirmRegistrationDto.cs
      EmailVerificationDto.cs
      LoginUserDto.cs
      LoginEventDto.cs
      UserAuthResult.cs
      RefreshTokenResponse.cs
      ProvisionSsoUserResponse.cs
      IdpDto.cs
    Interfaces/
      ICognitoService.cs
      IOidcAuthService.cs
      IOidcDiscoveryService.cs
      IIdpCacheInvalidator.cs
      IEmailVerificationService.cs
      IEmailVerificationCleanupService.cs
  Authorization/
    Commands/
      AddRole/
      UpdateRole/
    Queries/
      GetAllRoles/
    DTOs/
      UserRoleDto.cs

Auth.Infrastructure/
  Persistence/
    IfxDbContext.cs                 ← no move
    UnitOfWork.cs                   ← no move
    Migrations/                     ← no move (never move migrations)
  Users/
    Repositories/
      UserRepository.cs
      UserActivityLogRepository.cs
      EmailVerificationTokenRepository.cs
    Configurations/
      UserConfiguration.cs
      UserActivityLogConfiguration.cs
      EmailVerificationTokenConfiguration.cs
    Services/
      EmailVerificationService.cs
      EmailVerificationCleanupService.cs
  Identity/
    Configuration/
      CognitoSettings.cs
      CognitoOidcSettings.cs
    Services/
      CognitoService.cs
      CognitoOidcService.cs
      OidcDiscoveryService.cs
    Repositories/
      UserIdentityRepository.cs
      LoginEventRepository.cs
      LogoutEventRepository.cs
      RegistrationFlowEventRepository.cs
      IdpRepository.cs
    Configurations/
      UserIdentityConfiguration.cs
      LoginEventConfiguration.cs
      LogoutEventConfiguration.cs
      RegistrationFlowEventConfiguration.cs
      IdpConfiguration.cs
  Authorization/
    Repositories/
      UserRoleRepository.cs
    Configurations/
      UserRoleConfiguration.cs

Auth.Presentation/
  Extensions/                        ← no move
  Models/Responses/                  ← no move
  Users/
    Endpoints/
      UserEndpoints.cs
      UserEndpointExtensions.cs
      UserManagementEndpoints.cs
      UserManagementEndpointExtensions.cs
      EmailVerificationEndpoints.cs
      EmailVerificationEndpointExtensions.cs
    Requests/
      UpdateUserProfileRequest.cs
      VerifyEmailRequest.cs
  Identity/
    Endpoints/
      AuthEndpoints.cs
      AuthEndpointExtensions.cs
      OAuthEndpoints.cs
      OAuthEndpointExtensions.cs
      IdpEndpoints.cs
      IdpEndpointExtensions.cs
    Requests/
      ConfirmRegistrationRequest.cs
      LoginRequest.cs
      RefreshTokenRequest.cs
      RegisterRequest.cs
      RevokeTokenRequest.cs
      CreateIdpRequest.cs
      UpdateIdpRequest.cs
  Authorization/
    Endpoints/
      RoleEndpoints.cs
      RoleEndpointExtensions.cs
    Requests/
      AddRoleRequest.cs
      UpdateRoleRequest.cs
```

---

## Implementation Steps

Execute in this order to maintain compilation at each step.

### Step 1 — Create branch
```bash
git checkout -b feature/auth-subdomain-refactor
```

### Step 2 — Refactor Domain layer
1. Create new subdomain folders under `Auth.Domain/`
2. Move and rename files per the mapping table above
3. Update `namespace` declarations in each file
4. Update all `using` statements that reference old namespaces within the Domain project
5. Verify: `dotnet build IFX.Modules.Auth.Domain` compiles

### Step 3 — Refactor Application layer
1. Create subdomain folders under `Auth.Application/`
2. Move command, query, DTO, interface files per mapping
3. Update `namespace` declarations
4. Update all `using` statements in Application files (many reference Domain namespaces that changed in Step 2)
5. Verify: `dotnet build IFX.Modules.Auth.Application` compiles

### Step 4 — Refactor Infrastructure layer
1. Create subdomain folders under `Auth.Infrastructure/`
2. Move repository, service, configuration files per mapping
3. **Do NOT touch `Persistence/Migrations/`**
4. Update `namespace` declarations
5. Update `using` statements in `IfxDbContext.cs` (references entity types from Domain)
6. Update `DependencyInjection.cs` — service registrations reference new namespaces
7. Verify: `dotnet build IFX.Modules.Auth.Infrastructure` compiles

### Step 5 — Refactor Presentation layer
1. Create subdomain folders under `Auth.Presentation/`
2. Move endpoint and request model files per mapping
3. Update `namespace` declarations
4. Update `using` statements
5. Verify: `dotnet build IFX.Modules.Auth.Presentation` compiles

### Step 6 — Full build and test
```bash
dotnet build IFX.sln
dotnet test IFX.sln
```
All 252 unit tests must pass.

### Step 7 — Update test projects
Test projects reference Application/Domain types. Update `using` statements in:
- `IFX.Modules.Auth.Domain.Tests`
- `IFX.Modules.Auth.Application.Tests`
- `IFX.Modules.Auth.Infrastructure.Tests`
- `IFX.Modules.Auth.Presentation.Tests`
- `IFX.Tests.Common`

### Step 8 — Delete old empty folders
After all moves, delete the now-empty original folders:
- `Entities/`, `Enums/`, `Events/`, `Interfaces/`, `ValueObjects/` in Domain
- `Commands/`, `Queries/`, `DTOs/`, `Interfaces/` (except IUnitOfWork) in Application
- `Configuration/`, `Services/` in Infrastructure (the non-subdomain versions)
- `Endpoints/`, `Models/Requests/` in Presentation

---

## Risk Areas

| Risk | Mitigation |
|---|---|
| `UserRole` is referenced via navigation property on `User` | Cross-subdomain reference within same project is allowed — just needs correct `using` |
| `IfxDbContext` references all entity types | Update usings after Domain step; DbContext stays in `Persistence/` (shared) |
| `DependencyInjection.cs` in Infrastructure wires many services | Update last within each layer's step |
| `MappingProfile.cs` references DTOs and entities from both old namespaces | Update after Application DTO move |
| Migration snapshot references entity full type names | **Do not rename entity classes** — only move files and update namespaces. EF Core resolves entities by CLR type name, not namespace, so migrations are safe. |
| Tests reference Application/Domain types directly | Handle in Step 7 after all source projects compile |

---

## Constraints

- **No behavior changes** — pure structural reorganization
- **No new projects** — single module boundary preserved
- **No migration changes** — `Persistence/Migrations/` is never touched
- **No entity class renames** — only namespace and file location changes
- `Composition` project is unchanged (DI wiring at module level stays the same)
- Cross-subdomain references within the same project are permitted (subdomains are organizational, not module boundaries)
