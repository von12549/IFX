# Architecture

## Purpose
Defines the architectural invariants and patterns that must always hold in this codebase.

## Scope
- Layer responsibilities and dependencies
- Module structure
- Core design patterns

## Non-goals
- Implementation details (see `dotnet/*.md`)
- Technology-specific configurations

---

## Pattern: Modular Monolithic + Clean Architecture + Minimal APIs

```
IFX/
├── src/
│   ├── ApiHost/
│   │   └── IFX.ApiHost/      # Host application (references Composition + Abstractions)
│   ├── BuildingBlocks/
│   │   └── App.Abstractions/         # Shared interfaces (IModuleInstaller, IAppMigrator)
│   └── Modules/Auth/
│       ├── Domain/                   # Pure business logic (no dependencies)
│       ├── Application/              # Use cases with CQRS (→ Domain)
│       ├── Infrastructure/           # Data & AWS integration (→ Application)
│       ├── Presentation/             # Minimal API endpoints & models (→ Application)
│       └── Composition/              # Module entry point (wires all layers)
├── tests/                           # Test projects mirror src structure
└── docs/                            # Documentation
```

---

## Dependency Rules

**Rule:** Dependencies flow inward only. Outer layers depend on inner layers, never the reverse.

```
ApiHost → App.Abstractions (shared interfaces)
    ↓
Composition → Presentation → Application → Domain
    ↓              ↓              ↓
Infrastructure  Infrastructure  (transitive)
            ↘            ↗
              MediatR
```

**Rule:** Domain layer has ZERO external dependencies.

**Rule:** ApiHost references only Composition + App.Abstractions (single module dependency).

**Rule:** Cross-cutting concerns (auth, logging, health checks) live in ApiHost, not modules.

---

## Layer Responsibilities

### Domain Layer
- **Rule:** Contains only pure business logic, entities, value objects, domain events
- **Rule:** No references to infrastructure, frameworks, or external packages
- **Rule:** Entities use factory methods (`Entity.Create(...)`) not public constructors
- **Rule:** Value objects are immutable and self-validating

### Application Layer
- **Rule:** Orchestrates use cases via commands and queries (CQRS)
- **Rule:** One handler per command/query
- **Rule:** Uses Result pattern for operation outcomes
- **Rule:** Validators are co-located with commands

### Infrastructure Layer
- **Rule:** Implements repository interfaces defined in Domain
- **Rule:** Contains DbContext, entity configurations, external service clients
- **Rule:** No business logic - only data access and external integrations

### Presentation Layer
- **Rule:** Defines HTTP endpoints using Minimal APIs
- **Rule:** Delegates to MediatR handlers - no business logic
- **Rule:** Contains request/response DTOs organized by feature

### Composition Layer
- **Rule:** Single entry point for module registration
- **Rule:** Implements `IModuleInstaller` for discovery-based registration
- **Rule:** Wires all internal layers together

### BuildingBlocks (App.Abstractions)
- **Rule:** Contains only shared interfaces (`IModuleInstaller`, `IAppMigrator`)
- **Rule:** No implementation code
- **Rule:** Enables plugin-like module architecture

---

## Multi-IdP Architecture

**Rule:** Users are identified by `(Issuer, Subject)` tuple, not email alone.

**Rule:** User (core identity) is separate from UserIdentity (IdP-specific data).

**Rule:** One User can have many UserIdentities (supports multiple IdP accounts).

**Rule:** Primary lookup method: `GetByIssuerAndSubjectAsync(issuer, subject)`

**Rule:** Email lookups must be scoped to IdP: `GetByEmailAndIdpAsync(email, idpId)`

---

## Module Registration Pattern

**Rule:** Modules register via `IModuleInstaller` interface.

**Rule:** ApiHost discovers and invokes all registered installers.

```csharp
// Service registration
builder.Services.AddAuthModule(builder.Configuration);

// Endpoint mapping via discovery
var installers = app.Services.GetServices<IModuleInstaller>();
foreach (var installer in installers)
{
    installer.MapEndpoints(app);
}
```

---

## API Response Pattern

**Rule:** All endpoints return `ApiResponse<T>` for consistency.

**Rule:** Public endpoints: `/api/v1/{feature}/{action}`

**Rule:** Authenticated endpoints require JWT Bearer token.

**Rule:** Admin endpoints require `Admin` role via `RequireAuthorization()`.
