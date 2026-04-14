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
│   │   ├── App.Abstractions/         # Shared interfaces (IModuleInstaller, IAppMigrator)
│   │   └── IFX.BuildingBlocks.Security/ # Cross-cutting security (ICurrentUser, OPA, ABAC)
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

### BuildingBlocks (IFX.BuildingBlocks.Security)
- **Rule:** Cross-cutting security abstractions and implementations used by all modules
- Contains `ICurrentUser`, `IPermissionChecker`, `IOpaPolicyClient`, `IResourceAuthorizationService`
- Contains `OpaClient` (HttpClient-backed), `NullOpaPolicyClient` (dev stub), `OpaOptions`
- Contains `ForbiddenException` (→ 403 via middleware)
- Contains template-based ABAC: `IAbacTemplateRegistry`, `IAbacPolicyEngine`, `ConditionTemplate`, `AbacPolicy`, `AbacCondition`
- Contains policy resolver abstractions: `IAbacPolicyResolver`, `IAbacPolicyCache`, `StaticAbacPolicyResolver`
- **Rule:** No references to any business module (Auth, etc.) — depends only on framework packages

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

**Rule:** Tenant context is conveyed via the `X-Tenant-Id` request header. `CurrentUser.TenantId` reads this header, validates the value against the user's `tenant` claims, and falls back to the JWT `tenant_id` claim (primary tenant). The frontend sends `X-Tenant-Id` automatically via the axios interceptor; the value is persisted to `localStorage`.

**Rule:** The frontend drives tenant switching via `selectedTenantId` in `AuthContext`. All management pages reload when it changes — they do NOT pass it as a query parameter to API functions.

**Rule:** `Department` belongs to a `Tenant`. Users are linked to departments; the application layer enforces that a user's department belongs to one of their tenants.

## ABAC Authorization (OPA + Template Engine)

**Rule:** Authorization is two-layered — coarse-grained RBAC gate first, then fine-grained OPA policy decision.

**Rule:** Resource-level authorization is performed in the Application layer after loading the target resource (post-load pattern). Never authorize before loading.

**Rule:** OPA policies evaluate `input.subject.permissions` only — never raw role names. Policies are decoupled from role taxonomy.

**Rule:** `requiredPermission` in `IResourceAuthorizationService.AuthorizeAsync` is nullable. Pass `null` to skip the RBAC gate and let OPA be the sole decision maker (used for self-read operations where the user lacks the admin permission).

**Rule:** `OpaOptions.FailClosed = true` by default — OPA unavailability is treated as deny. Override to `false` only in local development.

**Rule:** `resource.tenant_id` in `OpaResourceAttributesBase` must match the caller's active tenant context (`ICurrentUser.TenantId`), not the resource entity's `PrimaryTenantId`. This ensures `same_tenant` passes when a user is operating in a non-primary tenant.

**Rule:** `Opa:Enabled = false` in `appsettings.Development.json` → `NullOpaPolicyClient` is registered (always allow). Never disable OPA in production.

### Template-Based ABAC

**Rule:** New resource types must use template-based ABAC (register conditions in `BuiltInTemplates`, store a `PolicyDefinition` row) — do not add a new per-resource `.rego` file.

**Rule:** `IAbacTemplateRegistry` is a singleton — thread-safe, registered once at startup with built-in templates.

**Rule:** `IAbacPolicyEngine` evaluates all conditions in an `AbacPolicy` with AND semantics — all must pass for allow.

### DB-Backed Policy Resolution

**Rule:** Policy resolution follows a strict 3-tier cascade: (1) tenant DB row → (2) platform DB row (`TenantId IS NULL`) → (3) static fallback → (4) null = deny.

**Rule:** `PolicyDefinition.TenantId = null` means platform-level (global default). A platform row covers all tenants that have no tenant-specific override.

**Rule:** Cache invalidation after any policy mutation is mandatory. Call `IAbacPolicyCache.Invalidate` for tenant rows and `IAbacPolicyCache.InvalidatePlatform` for platform rows.

**Rule:** Application handlers must depend on `IAbacPolicyResolver` and `IAbacPolicyCache` (BuildingBlocks interfaces) — never on `DbAbacPolicyResolver` (Infrastructure).

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

---

## Multi-Module Dependency Graph (Fund Registry)

```
ApiHost
  → Auth.Composition
  → CRM.Composition
  → Registry.Composition
  → Holdings.Composition
  → Transaction.Composition
  → Platform.Messaging.Composition
  → Platform.BackgroundJobs.Composition
  → Platform.Notifications.Composition

Transaction.Application
  → CRM.Abstractions          (ICrmReader — KYC check, party existence)
  → Registry.Abstractions     (IRegistryReader — class open for subscription)
  → Platform.Messaging.Abstractions  (IIntegrationEventBus — publish events)

Holdings.Application
  → Registry.Abstractions     (IIntegrationEventHandler<ClassStatusChangedEvent>)
  → Transaction.Abstractions  (IIntegrationEventHandler<TransactionProcessedEvent>)
  → Platform.Messaging.Abstractions

CRM.Application / Registry.Application
  → Platform.Messaging.Abstractions  (publish integration events)

No module references another module's Domain, Application, Infrastructure, or Presentation.
```

**Rule:** Cross-module reads go through `.Abstractions` reader interfaces only (`ICrmReader`, `IRegistryReader`, `IHoldingsReader`, `ITransactionReader`). Never inject another module's repository or DbContext.

**Rule:** Cross-module writes happen exclusively via integration events — no module calls another module's command handler or service directly.

**Rule:** Holdings is mutated only by integration events (`TransactionProcessedEvent`, `ClassStatusChangedEvent`). There are no HTTP write endpoints on Holdings.

**Rule:** All module databases use separate schemas (`"crm"`, `"registry"`, `"holdings"`, `"transaction"`) with no foreign key constraints across schemas. Referential integrity is enforced at the Application layer via cross-module reader calls before writing.
