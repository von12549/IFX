# Architecture

## Purpose
Defines the architectural invariants and patterns that must always hold in this codebase.

Current IAM ownership and detailed flows: [Plan 05 implementation](../docs/architecture/review/iam-platform-security.en.md). Old Auth directories and provider implementations are retired.

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
│   │   └── IFX.ApiHost/      # Host application (references Composition and neutral BuildingBlocks)
│   ├── BuildingBlocks/
│   │   ├── IFX.BuildingBlocks.Composition/         # IModuleInstaller composition SPI
│   │   └── IFX.BuildingBlocks.Security/ # Cross-cutting security (ICurrentUser, IPermissionChecker, ForbiddenException)
│   └── Modules/IAM/
│       ├── Domain/                   # Pure business logic (no dependencies)
│       ├── Application/              # Use cases with CQRS (→ Domain)
│       ├── Infrastructure/           # Persistence & port adapters (→ Application)
│       ├── Presentation/             # Minimal API endpoints & models (→ Application)
│       ├── Composition/              # Module entry point (wires all layers)
│       └── Contracts/V1/             # Public versioned protocols
├── tests/                           # Test projects mirror src structure
└── docs/                            # Documentation
```

---

## Dependency Rules

**Rule:** Dependencies flow inward only. Outer layers depend on inner layers, never the reverse.

```
Host → Module.Composition → Presentation → Application → Domain
                 ↓                            ↑
            Infrastructure ───────────────────┘
                 ↓
       Provider.Contracts (through consumer adapters)
```

**Rule:** Domain layer has ZERO external dependencies.

**Rule:** ApiHost references module Composition projects and permitted neutral BuildingBlocks; it does not reference module Application, Infrastructure or Presentation directly.

**Rule:** Host owns entry adaptation and middleware. IAM owns identity admission and access policies; Platform.Authentication/Authorization own technical execution.

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

### BuildingBlocks (IFX.BuildingBlocks.Composition)
- **Rule:** Contains the `IModuleInstaller` composition SPI; controlled migrations belong to DatabaseMigrator
- **Rule:** No implementation code
- **Rule:** Enables plugin-like module architecture

### BuildingBlocks (IFX.BuildingBlocks.Security)

- Contains only `ICurrentUser`, `IPermissionChecker`, `ForbiddenException`.
- IAM owns resource authorization, scoped policy resolution and current membership facts.
- Platform.Authorization owns neutral Contracts/Runtime and the OPA adapter; no AllowAll/NoOp authorization fallback.

---

## Multi-IdP Architecture

**Rule:** Users are identified by `(Issuer, Subject)` tuple, not email alone.

**Rule:** User (core identity) is separate from UserIdentity (IdP-specific data).

**Rule:** One User can have many UserIdentities (supports multiple IdP accounts).

**Rule:** Primary lookup method: `GetByIssuerAndSubjectAsync(issuer, subject)`

**Rule:** Email lookups must be scoped to IdP: `GetByEmailAndIdpAsync(email, idpId)`

---

## Multi-Tenant Architecture

**Rule:** `Tenant` is the top-level organisational unit. `Role`, `RoleGroup`, and `Idp` each carry a required `TenantId` FK.

**Rule:** Name uniqueness for Role and RoleGroup is scoped to `(TenantId, Name)` — the same name may exist in different tenants.

**Rule:** All list queries derive tenant context from `ICurrentUser.TenantId` — never from a query parameter. Handlers short-circuit with an empty result when `TenantId` is null; they never return cross-tenant data.

**Rule:** The HTTP entry adapter validates selected tenant against current IAM membership and establishes trusted execution context. VerifiedIdentityFacts refreshes active user, tenant membership and grants at authorization gates; token tenant/role claims are not authority.

**Rule:** The frontend drives tenant switching via `selectedTenantId` in `AuthContext`. All management pages reload when it changes — they do NOT pass it as a query parameter to API functions.

**Rule:** `Department` belongs to a `Tenant`. Users are linked to departments; the application layer enforces that a user's department belongs to one of their tenants.

## ABAC Authorization

- IAM.Access combines mandatory actor/scope/membership checks, RBAC and all applicable ABAC conditions; explicit self-read remains subject to ABAC.
- Resource modules own facts, tenant-restricted queries and enforcement; domain invariants still apply after permission succeeds.
- IAM selects current scoped policies and content-derived versions. Missing configuration, disabled/invalid policies and unavailable providers are distinct; only documented absence permits defaults.
- OPA disabled/unavailable and the legacy FailClosed=false setting never grant access. Removed NullOpaPolicyClient/IAbacPolicyCache types must not be reintroduced.
- Platform.Authorization accepts bounded neutral facts and conditions; provider representations stay in its OPA adapter. No cross-request policy/decision cache is enabled.
- GlobalRole is a separate platform scope, not tenant membership or an unrestricted bypass.

---

## Module Registration Pattern

**Rule:** Modules register via `IModuleInstaller` interface.

**Rule:** ApiHost discovers and invokes all registered installers.

```csharp
// Service registration
builder.Services.AddIamModule(builder.Configuration);

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

**Rule:** Administrative endpoints enforce named IAM permissions and applicable resource policies; a role name alone is insufficient.

---

## Multi-Module Dependencies

See the [current diagram](../docs/architecture/review/diagrams/01-current-architecture.md) and [generated project graph](../docs/architecture/review/evidence/plan05/current-dependency-graph.json).

- Host composes IAM, CRM, Registry, Holdings and Transaction through Composition.
- Applications define their own ports; Infrastructure adapters reference provider versioned Contracts. No module reads a foreign repository/DbContext or references foreign implementation layers.
- Integration events use governed Contracts with reliable Outbox/Inbox delivery; local domain events are not cross-module protocols.
- Holdings HTTP remains read-only; integration events apply its mutations.
- IAM retains logical Auth and physical auth ownership. Other schemas remain crm, registry, holdings and transaction; there are no cross-schema foreign keys.
