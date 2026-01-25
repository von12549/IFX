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
