# Key Decisions

## Purpose
Documents significant architectural and design decisions with rationale.

## Scope
- Why certain patterns were chosen
- Trade-offs considered
- Migration decisions

---

## ADR-001: CQRS with MediatR

**Decision:** Use CQRS pattern with MediatR for command/query separation.

**Rationale:**
- Clear separation of read and write operations
- Pipeline behaviors for cross-cutting concerns (validation, logging, transactions)
- Loose coupling between endpoints and business logic
- Easy to test handlers in isolation

**Trade-offs:**
- More boilerplate (command + handler + validator per operation)
- Indirection can make debugging harder

---

## ADR-002: Multi-IdP Architecture (January 2026)

**Decision:** Split User into User (core) + UserIdentity (IdP-specific) tables.

**Rationale:**
- Support multiple identity providers per user (Cognito, Google, Azure AD)
- `(Issuer, Subject)` tuple uniquely identifies each IdP identity
- Users can link multiple accounts to single profile
- Future-proof for SSO integrations

**Migration:** See `docs/MULTI_IDP_MIGRATION_SUMMARY.md`

---

## ADR-003: Modular Monolith with Composition Layer

**Decision:** Use Composition layer as single module entry point.

**Rationale:**
- ApiHost references only Composition (clean dependency graph)
- `IModuleInstaller` enables discovery-based registration
- Easy to add new modules without modifying Program.cs
- Encapsulates internal module structure

---

## ADR-004: Minimal APIs over Controllers

**Decision:** Use Minimal APIs instead of MVC Controllers.

**Rationale:**
- Less ceremony, more concise endpoint definitions
- Better performance (no controller instantiation)
- Static methods are easier to test
- Aligns with .NET 8 direction

---

## ADR-005: Value Objects for Domain Primitives

**Decision:** Wrap primitives in value objects (Subject, EmailAddress, DeviceInfo).

**Rationale:**
- Self-documenting code (parameter is `EmailAddress` not `string`)
- Validation at construction time
- Immutability prevents accidental mutation
- Encapsulates parsing logic (DeviceInfo parses User-Agent)

---

## ADR-006: Audit Trail Strategy

**Decision:** Separate event tables for different audit concerns.

**Rationale:**
- LoginEvent: Authentication attempts with tokens and device info
- LogoutEvent: Session duration tracking
- RegistrationFlowEvent: Registration lifecycle
- UserActivityLog: General activity (extensible via ActivityType enum)

**Trade-off:** Multiple tables vs single polymorphic event table. Chose multiple for query performance and schema clarity.

---

## ADR-007: Platform Pattern vs Modules Pattern (January 2026)

**Decision:** Maintain separate architectural patterns for Platform services and business Modules.

**Context:**
- Platform services (BackgroundJobs, Notifications) use a 3-project pattern: Abstractions → Infrastructure.{Provider} → Composition
- Business modules (Auth) use a 5-project Clean Architecture pattern: Domain → Application → Infrastructure → Presentation → Composition

**Rationale:**

| Concern | Platform Pattern | Modules Pattern |
|---------|-----------------|-----------------|
| **Purpose** | Cross-cutting infrastructure | Bounded business domains |
| **Domain Logic** | None - contracts/delegation only | Rich - entities, events, rules |
| **Business Ops** | Minimal | Heavy - CQRS with MediatR |
| **Swappability** | High (NoOp for testing, feature flags) | N/A - domain is unique |
| **Layers** | 3 projects | 5 projects |

**Guidelines:**

1. **Use Platform Pattern for:**
   - Infrastructure services (caching, messaging, file storage)
   - External provider integrations with simple contracts
   - Services that need NoOp/mock implementations for testing
   - Cross-cutting concerns shared by all modules

2. **Use Modules Pattern for:**
   - Business domains with rich logic (Orders, Payments, Inventory)
   - Features requiring CQRS command/query separation
   - Bounded contexts with domain entities and events
   - Areas with complex validation and business rules

3. **Cross-Module Communication:**
   - For modules that need to expose contracts to other modules, consider adding an `.Abstractions` project
   - This allows `ModuleB` to depend on `ModuleA.Abstractions` without full Domain/Application coupling

**Trade-offs:**
- Two patterns to learn vs one unified approach
- Chose separation because forcing Platform's simple pattern onto Modules loses Clean Architecture benefits (domain isolation, repository abstraction, CQRS)

**Reference:** See `/.claude/playbooks/pattern-selection.md` for decision flowchart.

---

## ADR-008: OPA + ABAC Authorization (March 2026)

**Decision:** Introduce OPA (Open Policy Agent) as a policy decision engine for fine-grained, resource-level authorization, layered on top of the existing RBAC model.

**Rationale:**
- RBAC alone cannot express resource-level constraints (same tenant, ownership, sensitivity)
- OPA decouples policy logic from application code — Rego policies are versioned separately
- `IResourceAuthorizationService` provides a clean abstraction: Application layer calls it without knowing OPA exists
- Fail-closed by default: OPA unavailability = deny, not allow
- `NullOpaPolicyClient` (always-allow) makes local development viable without running OPA

**Authorization flow:**
```
Request → RBAC gate (optional, skippable) → OPA policy evaluation → allow/deny
```

**Key design choices:**
- `requiredPermission` is nullable — pass `null` to skip RBAC gate (e.g. self-reads where the user lacks the admin permission)
- OPA policies evaluate `input.subject.permissions` only, never role names — decoupled from role taxonomy
- Post-load pattern: load the resource first, then authorize; avoids phantom authorization on non-existent resources
- `IFX.BuildingBlocks.Security` is a new cross-cutting project; it has zero references to any business module

**Trade-offs:**
- OPA sidecar adds operational complexity (healthcheck, container startup)
- Policy and application code can drift if not maintained together
- Chose OPA over in-process Rego eval for future flexibility (bundle server, remote eval)

---

## ADR-009: X-Tenant-Id Header for Tenant Context (March 2026)

**Decision:** Replace `?tenantId=` query parameters with an `X-Tenant-Id` request header for tenant context on management list endpoints.

**Rationale:**
- Query params on GET list endpoints leaked tenant context into URLs and logs
- Headers are the standard HTTP mechanism for per-request ambient context (like `Authorization`)
- The selected tenant is operator state (which tenant am I working in), not a filter parameter
- `ICurrentUser.TenantId` can now provide tenant context uniformly to all handlers — no need to thread it through query/command records
- ABAC `same_tenant` enforcement works correctly: subject tenant and resource tenant are both derived from the same active context

**Security property:**
- `CurrentUser.TenantId` validates the header value against `tenant` claims (populated at login from the user's actual tenant memberships) before returning it. A user cannot spoof a tenant they don't belong to.

**Frontend contract:**
- `tokenStorage.setSelectedTenantId` persists the value to `localStorage`
- `apiClient` request interceptor adds `X-Tenant-Id: <value>` to every request automatically
- Pages still react to `selectedTenantId` changes via `useEffect([selectedTenantId])` to reload data

**Trade-offs:**
- Headers are less visible than query params for debugging (use browser devtools Network tab)
- Chose headers over session/cookie storage to stay stateless on the server side

---

## ADR-010: Template-Based ABAC + DB-Backed Policy Storage (March 2026)

**Decision:** Replace per-resource Rego files for new resource types with reusable C# condition templates (`ConditionTemplate`) evaluated by a single generic Rego policy. Store active policies in a `PolicyDefinitions` database table with a 3-tier resolver (tenant override → platform default → static fallback → deny).

**Rationale:**
- Per-resource Rego files don't scale — each new resource type requires a new `.rego` file, policy deployment, and OPA reload
- `ConditionTemplate` objects are C# code (unit-testable, refactor-friendly, type-safe) while staying OPA-compatible
- A single `template_abac.rego` handles all template-based resources; the evaluation logic lives in `AbacPolicyEngine`
- DB storage enables runtime policy customization per tenant without redeployment
- Platform rows (`TenantId IS NULL`) provide a single global default that covers all tenants without an explicit override, eliminating the need for per-tenant seed data

**3-tier cascade design:**
```
Tenant DB row → Platform DB row → Static fallback → null (deny)
```
- Tier 1 (tenant) allows tenants to override the platform default
- Tier 2 (platform) is the default for all tenants — seeded via EF migration
- Tier 3 (static) is a last resort for resources not yet migrated to DB storage
- null (deny) is fail-closed behavior when no policy exists

**Cache strategy:**
- `IMemoryCache` with separate keys for tenant and platform entries
- `IAbacPolicyCache` interface on BuildingBlocks so Application handlers can invalidate without referencing Infrastructure

**Trade-offs:**
- Template-based approach is less expressive than raw Rego (no arbitrary Rego logic per resource)
- Chose this trade-off because the common conditions (`SameTenant`, `CreatedByMe`) cover the majority of use cases, and the static fallback + raw Rego path remains available for complex policies
- DB-backed policies add a DB round-trip per authorization; mitigated by `IMemoryCache`

---

## ADR-011: Integration Event Bus — Platform.Messaging (April 2026)

**Decision:** Cross-module communication uses an in-process `IIntegrationEventBus` (`InMemoryIntegrationEventBus`) registered as a Platform service. Integration event contracts live in each module's `.Abstractions` project. No module references another module's Domain, Application, Infrastructure, or Presentation layers.

**Rationale:**
- Option A (.Abstractions shared references) creates compile-time coupling between modules — a change in CRM.Abstractions forces recompilation of all consumers
- Option B (integration events via a central bus) preserves module isolation while still allowing data sharing through well-typed event contracts
- In-memory dispatch (same thread, same DI scope) keeps the transaction boundary simple and avoids distributed systems complexity for the current scale
- Swapping to an external broker (RabbitMQ, Azure Service Bus) later requires only a new `IFX.Platform.Messaging.Infrastructure.{Provider}` project and a config change — no Application layer changes

**Event contract ownership:**
- Each module owns its own event types in its `.Abstractions` project
- Consumers reference only `.Abstractions`, never the emitting module's Application or Infrastructure

**Trade-offs:**
- In-memory bus is lost on process crash; no message durability
- Sequential dispatch — a slow handler blocks subsequent handlers
- Chose this trade-off: durability and parallelism can be added in the Infrastructure layer without changing Application code

---

## ADR-012: Fund Registry Domain Modules (April 2026)

**Decision:** The Fund Registry system is split into four domain modules (CRM, Registry, Holdings, Transaction) following the existing 5-layer Clean Architecture + CQRS pattern. Holdings is the authoritative unit ledger, updated exclusively via integration events — never via direct HTTP writes.

**Module boundaries:**
- **CRM** — Party + Investor lifecycle, KYC tracking, many-to-many Party↔Investor relationships
- **Registry** — Three-tier Product (Scheme) → Fund → FundClass hierarchy; `Product` holds regulatory identity (ARSN, APIR, ISIN), issuer metadata, PDS reference; `Fund.ProductId` is a nullable FK — standalone funds remain valid; FundClass carries fee rates, NAV frequency, and class currency
- **Holdings** — Running unit balances per (Investor, FundClass); read-only HTTP; mutated by `TransactionProcessedEvent` and `ClassStatusChangedEvent`
- **Transaction** — Subscription / Redemption / Transfer / Switch; validates KYC + class status via cross-module readers; `Process(navPrice)` calculates units and publishes `TransactionProcessedEvent`

**Cross-module referential integrity (no FK across modules):**
- Application layer calls `ICrmReader.IsInvestorKycApprovedAsync` and `IRegistryReader.IsClassOpenForSubscriptionAsync` before creating transactions
- No foreign key constraints across module database schemas — integrity enforced at the application boundary
- Holdings upserts a new `Holding` row if none exists for a (TenantId, InvestorId, ClassId) triple

**Entity naming:**
- `Party` (not Account) — represents a legal entity acting as Distributor, Custodian, Fund Manager, etc.
- `FundClass` (not Class) — avoids collision with the C# `class` keyword
- `Product` (not Scheme) — used in code; `ProductType` carries `ManagedFund | ETF | Superannuation | IDPS | LIT | Other`

**Soft delete everywhere:**
- `DeletePartyCommand`, `DeleteInvestorCommand`, `DeleteFundCommand`, `DeleteClassCommand`, `DeleteProductCommand` all set `Status = Closed`
- `IsActive` ABAC template enforces closed entities are read-only

---

## ADR-013: Registry Product Layer — Product → Fund → FundClass Hierarchy (April 2026)

**Decision:** Introduce a `Product` entity as an optional parent of `Fund` in the Registry module, establishing the industry-standard three-tier hierarchy aligned with the Taurus schema (Product/Scheme → Sub-fund → Class).

**Rationale:**
- Industry standard (ASIC, APRA, Taurus) separates regulatory scheme identity (Product) from investment vehicle (Fund) from investor unit series (FundClass)
- Regulatory fields (ARSN, APIR, ISIN) belong at the Product level — they identify the scheme, not any single sub-fund
- `Fund.ProductId` is nullable so all existing funds remain valid with no migration of data; Product association is opt-in
- `OnDelete(Restrict)` on the FK prevents accidental Product deletion while funds reference it

**Key design choices:**
- `ProductType` enum (`ManagedFund | ETF | Superannuation | IDPS | LIT | Other`) is scheme-level classification, distinct from `FundType` which is vehicle-level
- `ProductStatus` enum (`Active | Closed | Suspended`) mirrors `FundStatus`/`ClassStatus` pattern
- `GET /api/v1/product/{id}/funds` provides the downward navigation from Product to its Funds
- `Fund.SetProduct(Guid?)` / `UpdateFundCommand.ClearProduct = true` cleanly manages the nullable association without a separate endpoint

**Migration:** Additive delta migration `AddProduct` adds `registry.Products` table and nullable `ProductId` FK on `registry.Funds` — zero downtime, no existing row touched.

---

## ADR-014: DateTimeOffset for All Timestamps (April 2026)

**Decision:** Replace all `DateTime` fields with `DateTimeOffset` across every domain entity, DTO, DbContext, and event type in the solution. SQL Server columns migrate from `datetime2` to `datetimeoffset(7)`.

**Rationale:**
- `DateTime` has no offset information — callers must assume UTC by convention, but the type itself doesn't enforce it
- `DateTimeOffset` carries the offset (`+00:00` for UTC), making the round-trip unambiguous in JSON responses and SQL storage
- Aligns with ISO 8601 and the Calastone API contract which uses offset-qualified timestamps
- Existing UTC timestamps are preserved exactly — SQL Server `CONVERT(datetimeoffset, datetime2_value)` appends `+00:00` without changing the point-in-time

**Key changes:**
- `IAuditableEntity.CreatedAt/UpdatedAt` → `DateTimeOffset`
- All `SaveChangesAsync` overrides → `DateTimeOffset.UtcNow`
- Auth non-audit fields: `LoginEvent.LoginTimestamp`, `EmailVerificationToken.ExpiresAt/UsedAt`, `UserGlobalRole.AssignedAt`, `LogoutEvent.LogoutTimestamp`, `UserActivityLog.Timestamp`, `UserIdentity.LastSyncedAt`
- CRM: `Investor.KycReviewedAt`; Holdings: `Holding.LastTransactionAt`
- All 5 modules received `AlterAuditColumnsToDateTimeOffset` EF migrations

**Rule established:** All new timestamp fields must use `DateTimeOffset`, never `DateTime`. This is now a Golden Rule in CLAUDE.md.

**Trade-offs:**
- JSON responses change from `"2026-04-20T12:00:00"` to `"2026-04-20T12:00:00+00:00"` — more explicit, valid ISO 8601
- Clients that parse timestamps as `DateTime` will still work (the offset is ignored but the point-in-time is correct)

---

## ADR-015: Order Instruction Model — Calastone STP Integration Layer (April 2026)

**Decision:** Introduce an `Order` aggregate root as the top-level investor instruction entity, with `Transaction` records as execution legs, aligned with the Calastone Executing Party REST API (V3.0) and ISO 20022 fund industry STP patterns.

**Rationale:**
- `Transaction` conflated instruction (what the investor wants) with execution record (what happened) — causing structural gaps: Switch used a `TargetClassId` shortcut; no accept/reject lifecycle; no external order references; no charge/commission/tax breakdown
- The Calastone REST API contract requires Order-level lifecycle: `Submitted → Accepted → PriceConfirmed | Rejected | Cancelled`
- Separating Order (instruction) from Transaction (leg) makes Switch orders natural: one Order, two legs (Redemption + Subscription)
- Backward compatible: existing `POST /api/v1/transaction/{subscription,redemption,switch}` endpoints remain unchanged

**Key design choices:**
- `Transaction.OrderId` is nullable FK — legacy transactions (pre-STP) have `null`; new STP transactions are always created via an Order
- JSON columns for `ChargeDetails[]`, `CommissionDetails[]`, `TaxDetails[]` — simpler than normalized child tables; charges are read-only after confirmation
- `ExternalFundIdentifier` (ISIN/APIR/CUSIP/SEDOL) as a flat owned value object on Transaction legs
- `OrderReference` uniqueness scoped to `(TenantId, OrderReference)` — ordering party controls the ref

**New endpoints:** `POST/GET /api/v1/order`, `GET /api/v1/order/{id}`, `POST /api/v1/order/{id}/{accept,reject,confirm}`, `DELETE /api/v1/order/{id}`

**Trade-offs:**
- Existing `CreateSubscription/Redemption/Switch` handlers remain unchanged (parallel path) — a later migration task will wire them through Order internally
- `Transfer` type has no Calastone equivalent — remains Transaction-only
