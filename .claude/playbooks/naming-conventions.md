# Naming Conventions Playbook

## Purpose
This document defines the mandatory naming conventions for all code artifacts in this repository. Claude MUST follow these conventions when creating or modifying code.

---

## Golden Rules

1. **Consistency over preference** - Follow existing patterns, even if you prefer alternatives
2. **Names reveal intent** - A name should explain what something does, not how
3. **Avoid abbreviations** - Except for well-known acronyms (DTO, JWT, IdP, SSO)
4. **Match the domain language** - Use terms from the glossary

---

## C# General Conventions

### Casing Rules

| Element | Casing | Example |
|---------|--------|---------|
| Classes, Records, Structs | PascalCase | `UserProfile`, `LoginUserCommand` |
| Interfaces | PascalCase with `I` prefix | `IUserRepository`, `ICognitoService` |
| Methods | PascalCase | `GetUserById`, `ValidateToken` |
| Properties | PascalCase | `IsActive`, `CreatedAt` |
| Public fields | PascalCase | `MaxRetryCount` |
| Private fields | _camelCase (underscore prefix) | `_userRepository`, `_logger` |
| Parameters | camelCase | `userId`, `accessToken` |
| Local variables | camelCase | `currentUser`, `isValid` |
| Constants | PascalCase | `DefaultPageSize`, `MaxLoginAttempts` |
| Enums | PascalCase (type and values) | `LoginResult.Success` |

### Boolean Naming

**Pattern:** Use `Is`, `Has`, `Can`, `Should` prefixes for boolean properties.

| Prefix | Usage | Example |
|--------|-------|---------|
| `Is` | State or condition | `IsActive`, `IsConfirmed`, `IsPrimary` |
| `Has` | Ownership or presence | `HasExpired`, `HasPermission` |
| `Can` | Capability | `CanEdit`, `CanDelete` |
| `Should` | Recommendation | `ShouldRetry`, `ShouldNotify` |

---

## Project & Namespace Structure

### Module Namespace Pattern
```
IFX.Modules.{Module}.{Layer}
```

| Layer | Namespace | Example |
|-------|-----------|---------|
| Domain | `.Domain` | `IFX.Modules.Auth.Domain` |
| Application | `.Application` | `IFX.Modules.Auth.Application` |
| Infrastructure | `.Infrastructure` | `IFX.Modules.Auth.Infrastructure` |
| Presentation | `.Presentation` | `IFX.Modules.Auth.Presentation` |

### Folder Structure Within Layers

```
Domain/
├── Common/           # Base classes, interfaces
├── Entities/         # Aggregate roots and entities
├── ValueObjects/     # Immutable value types
├── Enums/            # Domain enumerations
├── Events/           # Domain events
└── Interfaces/
    └── Repositories/ # Repository interfaces

Application/
├── Commands/
│   └── {ActionEntity}/
│       ├── {ActionEntity}Command.cs
│       ├── {ActionEntity}CommandHandler.cs
│       └── {ActionEntity}CommandValidator.cs
├── Queries/
│   └── {GetEntity}/
│       ├── {GetEntity}Query.cs
│       └── {GetEntity}QueryHandler.cs
├── DTOs/             # Data transfer objects
├── Common/           # Result, errors
└── Interfaces/       # Service interfaces

Infrastructure/
├── Persistence/
│   ├── Configurations/  # EF entity configs
│   └── Repositories/    # Repository implementations
└── Services/            # External service implementations

Presentation/
└── Endpoints/
    └── {Feature}/
        └── {Feature}Endpoints.cs
```

---

## CQRS Naming Patterns

### Commands (Write Operations)

| Component | Pattern | Example |
|-----------|---------|---------|
| Command | `{Action}{Entity}Command` | `RegisterUserCommand`, `UpdateIdpCommand` |
| Handler | `{Action}{Entity}CommandHandler` | `RegisterUserCommandHandler` |
| Validator | `{Action}{Entity}CommandValidator` | `RegisterUserCommandValidator` |
| Response | `{Action}{Entity}Response` | `RegisterUserResponse` |

**Action Verbs:**
- `Register` - Create with registration flow
- `Create` - Simple creation
- `Update` - Modify existing
- `Delete` - Remove
- `Add` - Add to collection
- `Remove` - Remove from collection
- `Sync` - Synchronize with external system
- `Provision` - Auto-create based on external data
- `Revoke` - Invalidate (tokens, permissions)

### Queries (Read Operations)

| Component | Pattern | Example |
|-----------|---------|---------|
| Query | `Get{Entity}{Qualifier}Query` | `GetUserProfileQuery`, `GetAllUsersQuery` |
| Handler | `Get{Entity}{Qualifier}QueryHandler` | `GetUserProfileQueryHandler` |

**Query Qualifiers:**
- `GetAll{Entity}s` - List all (paginated)
- `Get{Entity}By{Key}` - Single by identifier
- `Get{Entity}{Aspect}` - Specific aspect (e.g., `GetUserLoginHistory`)

---

## Domain Layer Naming

### Entities

| Component | Pattern | Example |
|-----------|---------|---------|
| Entity class | Singular noun | `User`, `LoginEvent`, `UserRole` |
| Base class | `BaseEntity` | `BaseEntity` |
| Auditable interface | `IAuditableEntity` | `IAuditableEntity` |

**Entity Conventions:**
- Private parameterless constructor for EF Core: `private User() { }`
- Static factory method: `public static User Create(...)`
- Private setters: `public string Name { get; private set; }`
- Collection backing fields: `private readonly List<T> _items = new();`
- Read-only collection exposure: `public IReadOnlyCollection<T> Items => _items.AsReadOnly();`

### Value Objects

| Component | Pattern | Example |
|-----------|---------|---------|
| Value object | Descriptive noun | `EmailAddress`, `Subject`, `DeviceInfo` |
| Value property | `Value` (for single-value) | `public string Value { get; }` |

**Value Object Conventions:**
- Immutable (private setters or init-only)
- Static `Create` factory method with validation
- Implement `IEquatable<T>`
- Override `Equals`, `GetHashCode`, `==`, `!=`

### Domain Events

| Component | Pattern | Example |
|-----------|---------|---------|
| Domain event | `{Entity}{Action}DomainEvent` | `UserRegisteredDomainEvent` |

**Action suffixes:** `Registered`, `Confirmed`, `LoggedIn`, `LoggedOut`, `Synced`

### Enums

| Component | Pattern | Example |
|-----------|---------|---------|
| Enum type | Singular noun | `LoginResult`, `IdpType`, `ActivityType` |
| Enum values | PascalCase | `LoginResult.Success`, `IdpType.Internal` |

---

## Infrastructure Layer Naming

### Repositories

| Component | Pattern | Example |
|-----------|---------|---------|
| Interface (Domain) | `I{Entity}Repository` | `IUserRepository` |
| Implementation | `{Entity}Repository` | `UserRepository` |

**Repository Method Naming:**
| Operation | Pattern | Example |
|-----------|---------|---------|
| Get by ID | `GetByIdAsync` | `GetByIdAsync(Guid id)` |
| Get single | `Get{Criteria}Async` | `GetByEmailAsync(string email)` |
| Get multiple | `GetAll{Criteria}Async` | `GetAllActiveAsync()` |
| Check existence | `ExistsAsync` | `ExistsAsync(Guid id)` |
| Add | `AddAsync` | `AddAsync(User user)` |
| Update | `UpdateAsync` | `UpdateAsync(User user)` |
| Delete | `DeleteAsync` | `DeleteAsync(Guid id)` |

### Services

| Component | Pattern | Example |
|-----------|---------|---------|
| Interface | `I{Provider}Service` | `ICognitoService`, `IIdpConfigurationService` |
| Implementation | `{Provider}Service` | `CognitoService`, `IdpConfigurationService` |

### EF Core Configurations

| Component | Pattern | Example |
|-----------|---------|---------|
| Configuration | `{Entity}Configuration` | `UserConfiguration` |

---

## Presentation Layer Naming

### Endpoints

| Component | Pattern | Example |
|-----------|---------|---------|
| Endpoint class | `{Feature}Endpoints` | `AuthEndpoints`, `UserEndpoints` |
| Route group | `/api/v1/{feature}` | `/api/v1/auth`, `/api/v1/user` |

**HTTP Method Mapping:**
| Method | Action | Route Example |
|--------|--------|---------------|
| GET | Retrieve | `GET /api/v1/users/{id}` |
| POST | Create/Action | `POST /api/v1/auth/login` |
| PUT | Full update | `PUT /api/v1/users/{id}` |
| PATCH | Partial update | `PATCH /api/v1/users/{id}` |
| DELETE | Remove | `DELETE /api/v1/users/{id}` |

### DTOs

| Component | Pattern | Example |
|-----------|---------|---------|
| Request DTO | `{Action}{Entity}Dto` | `RegisterUserDto`, `LoginUserDto` |
| Response DTO | `{Entity}{Aspect}Dto` | `UserProfileDto`, `LoginEventDto` |

---

## Database Naming

### Tables

| Element | Convention | Example |
|---------|------------|---------|
| Schema | Lowercase module name | `auth` |
| Table name | PascalCase plural | `Users`, `LoginEvents`, `Idps` |
| Primary key | `Id` | `Id` (Guid) |
| Foreign key | `{Entity}Id` | `UserRoleId`, `UserId` |

### Columns

| Element | Convention | Example |
|---------|------------|---------|
| Regular column | PascalCase | `DisplayName`, `IsActive` |
| Timestamp | `{Action}At` | `CreatedAt`, `UpdatedAt`, `ExpiresAt` |
| Boolean | `Is{Adjective}` | `IsActive`, `IsPrimary` |

---

## File Naming

| File Type | Pattern | Example |
|-----------|---------|---------|
| C# class | `{ClassName}.cs` | `User.cs`, `RegisterUserCommand.cs` |
| Interface | `I{Name}.cs` | `IUserRepository.cs` |
| Test class | `{ClassUnderTest}Tests.cs` | `UserTests.cs`, `RegisterUserCommandTests.cs` |

---

## Anti-Patterns to Avoid

| Bad | Good | Reason |
|-----|------|--------|
| `UserManager` | `UserService` or `IUserRepository` | Manager is vague |
| `UserHelper` | Specific method on entity/service | Helper is a code smell |
| `UserUtils` | Specific extension methods | Utils is non-descriptive |
| `UserInfo` | `UserProfile` or `UserDto` | Info is redundant |
| `DoSomething` | `{Verb}{Noun}` | Be specific |
| `HandleUser` | `CreateUser`, `UpdateUser` | Handle is vague |
| `ProcessData` | `ValidateInput`, `TransformResponse` | Process is unclear |
| `data`, `info`, `item` | Descriptive names | Too generic |
| `temp`, `x`, `i` (except loops) | Meaningful names | Non-descriptive |

---

## Quick Reference Card

```
Commands:     {Action}{Entity}Command          → RegisterUserCommand
Queries:      Get{Entity}{Qualifier}Query      → GetUserProfileQuery
Handlers:     {Command/Query}Handler           → RegisterUserCommandHandler
Validators:   {Command}Validator               → RegisterUserCommandValidator
Entities:     Singular noun                    → User, LoginEvent
ValueObjects: Descriptive noun                 → EmailAddress, DeviceInfo
Repositories: I{Entity}Repository              → IUserRepository
Services:     I{Provider}Service               → ICognitoService
DTOs:         {Context}Dto                     → UserProfileDto
Endpoints:    {Feature}Endpoints               → AuthEndpoints
Events:       {Entity}{Action}DomainEvent      → UserRegisteredDomainEvent
Enums:        Singular noun                    → LoginResult, IdpType
```

---

End of playbook.
