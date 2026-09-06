# Target IFX Contracts, Adapters, and Events architecture

> Document status: architecture review proposal  
> Implementation status: not implemented  
> Purpose: baseline for later implementation planning, architecture rules, and test strategy.

## 1. Goals and non-goals

The target preserves the low latency and operational convenience of a modular monolith while strengthening compile-time independence, business responsibility ownership, data ownership, and future microservice extractability.

It does not require an immediate microservice split, and it does not recommend localhost HTTP inside one ApiHost merely to imitate microservices. In-process calls remain a valid and efficient module API when they cross only stable Contracts and Adapters.

Related diagrams:

- [Target architecture](diagrams/03-target-contracts-adapters-events-architecture.md)
- [Target synchronous Contract flow](diagrams/04-target-synchronous-contract-flow.md)
- [Target durable Integration Event flow](diagrams/05-target-integration-event-flow.md)
- [Target DI composition flow](diagrams/06-target-di-composition-flow.md)

## 2. Core terminology

### 2.1 Contracts

Contracts are the stable protocols a module promises to external consumers. They are neither a new Clean Architecture business ring nor an implementation assembly. The existing `<Module>.Abstractions` responsibility should be narrowed and explicitly treated as `<Module>.Contracts`.

Contracts may contain:

- small, cohesive synchronous query or command interfaces;
- deliberately designed request and response DTOs;
- Integration Event schemas; and
- required public error codes, enums, and version information.

Contracts must not contain:

- handlers, repositories, units of work, or DbContexts;
- EF entities, internal domain entities, or internal Application DTOs;
- DI registration, message transport implementations, or HTTP clients; or
- business rules and data-access logic.

Contracts never load implementations. The module that owns a capability implements it, and that module's Composition project registers the implementation in the shared DI container.

### 2.2 Consumer-owned Port

A consumer Application defines the capability required by its own use case. Transaction may, for example, define `IAccountComplianceSource`. This Port describes what Transaction needs, not how CRM supplies it.

In strict mode, Transaction.Application does not reference CRM.Contracts directly. The consumer core is therefore insulated from provider types, transport choices, and version changes.

### 2.3 Integration Adapter

An Integration Adapter is an outer adapter whose architectural role belongs to Infrastructure. Initially it can live under:

```text
IFX.Modules.Transaction.Infrastructure/Integrations/CRM
```

It only needs a separate project such as `IFX.Modules.Transaction.Integration.CRM` when adapter volume, technology differences, or independent deployment needs justify the additional project. Even then, it is not a new business ring.

An outbound adapter:

- implements a consumer-owned Application Port;
- references provider Contracts;
- translates requests and responses;
- normalizes technical outcomes such as NotFound, Denied, Unavailable, and Timeout; and
- can later change from an in-process implementation to an HTTP/gRPC client.

An inbound event adapter:

- references producer Event Contracts;
- validates the envelope and schema version;
- performs Inbox idempotency checks;
- translates an external event into a consumer-owned Application command; and
- does not contain consumer business rules.

### 2.4 Presentation

Presentation is an inbound HTTP adapter, not a business interface for ApiHost. It owns routing, model binding, HTTP authorization metadata, and conversion to HTTP results before invoking Application. It contains no business rules and does not access a database directly.

### 2.5 Composition and ApiHost

A module implements its own capabilities, the module Composition project registers those implementations, and ApiHost invokes every module registration entry point before building the shared DI container.

```text
Implementation ownership: capability-owning module
Registration ownership: that module's Composition project
Global loading: ApiHost composition root
```

ApiHost should not know or register concrete module business implementations; doing so would turn it into a coupling hub.

## 3. Target compile-time dependency rules

### 3.1 Domain

- Contains domain entities, value objects, domain services, domain events, and invariants only.
- Does not reference its Contracts, Application, Infrastructure, Presentation, or another business module.
- Does not contain Integration Events; Domain Events and Integration Events are distinct.

### 3.2 Application

- References its own Domain.
- May reference and implement its own Contracts to expose a public facade or publish module-owned Integration Events.
- Defines consumer-owned ports required by its use cases.
- Does not reference another business module's Contracts in strict mode.
- Does not reference DbContext, EF Core, HTTP clients, or broker implementations.

### 3.3 Contracts

- Does not reference its Application, Infrastructure, or Presentation.
- Does not reference another business module.
- Preferably depends only on base .NET types; an event envelope may depend only on a tiny, stable messaging-contract assembly.
- Never creates implicit coupling by sharing domain types.

### 3.4 Infrastructure and Integration Adapters

- Infrastructure implements technical ports declared by its Application or Domain.
- An outbound adapter may reference provider Contracts but never the provider Application, Domain, or Infrastructure.
- It never queries or updates another module's DbContext, schema, or repository.
- An inbound message handler translates an external event into a module-owned Application command.

### 3.5 Presentation

- References its own Application and, where necessary, dedicated HTTP models.
- Does not use repositories or DbContexts directly.
- Does not expose another module's Application implementation for direct consumption.

### 3.6 Composition

- Is the only project that knows its module Contracts, Application, Infrastructure, Presentation, and Adapter implementations together.
- Registers a public Contract to the module Application facade.
- Registers a consumer Port to an Integration Adapter.
- Registers inbound Integration Event handlers.

## 4. Synchronous cross-module queries

Use a synchronous Contract when a consumer must obtain a reasonably current provider fact during the request. KYC and Fund Class availability currently fit this model in IFX.

The target path is:

```text
Transaction.Application
  → Transaction-owned Port
  → Transaction CRM/Registry Adapter
  → provider Contracts
  → provider Application Facade
  → provider Domain/Repository Port
  → provider Infrastructure
```

Public Contracts should be grouped by cohesive capability, not by an ever-growing generic Reader. The desired ownership is:

- CRM exposes account-compliance facts, not the decision that a Transaction order may be created.
- Registry exposes Fund Class status or subscription-availability facts.
- Transaction applies its own order-creation policy to those facts.

A public result should not be Boolean-only. It must at least distinguish a business rejection, not found, denied, and provider unavailable outcome. Reason code, evaluated-at time, and source version may also be required.

A synchronous query still has temporal coupling and a check-then-act race. If the fact must remain valid through a later commit, use an expiring versioned authorization/reservation token, an explicit workflow, or reconsider the module boundary.

## 5. Integration Events

An Integration Event represents a committed cross-module business fact such as `TransactionProcessed`. It is not a current-state query and must not directly drive another module write before the producer transaction commits.

The target reliable process is:

1. The producer saves aggregate changes and an Outbox record in one local transaction.
2. After commit, an Outbox Dispatcher asynchronously publishes a versioned event.
3. Transport provides at-least-once delivery.
4. The consumer inbound adapter checks an Inbox using EventId and consumer identity.
5. The adapter maps the event to a consumer-owned Application command.
6. Consumer state and the Inbox processed record commit in one consumer-local transaction.
7. Failures retry with backoff, enter a dead-letter path after the policy limit, and remain observable and replayable.

The producer owns the event schema, names it as a past-tense fact, and evolves it compatibly. The recommended envelope includes EventId, OccurredAt, CorrelationId, CausationId, TenantId, and schema version.

Domain Events and Integration Events must remain distinct. A Domain Event is internal to the model; an Integration Event is a public boundary protocol normally mapped from a domain outcome at the Application commit boundary.

## 6. Event Notification and local projections

When reads are frequent, short-lived staleness is acceptable, and synchronous availability coupling is undesirable, a consumer may subscribe to Event-Carried State Transfer and maintain a local projection.

Before introducing a projection, the design must provide:

- a complete event set required to rebuild state;
- bootstrap, snapshot, and replay processes;
- message ordering or version-conflict handling;
- idempotent consumption;
- missing-event detection and periodic reconciliation; and
- an explicit acceptable-staleness interval.

The current CRM events cannot fully reconstruct account KYC, so the existing event stream cannot directly replace the synchronous query.

## 7. Communication selection

| Scenario | Recommended mechanism | Primary cost |
|---|---|---|
| A command needs a reasonably current fact | Synchronous Contract and Adapter | Temporal coupling, timeout, and race |
| A committed source fact triggers downstream work | Integration Event with Outbox/Inbox | Eventual consistency, retries, and operations |
| High-volume reads tolerate short staleness | Event-Carried State Transfer and local projection | Duplication, rebuild, and reconciliation |
| A hard atomic invariant spans modules | Reconsider boundary or use explicit reservation/workflow | More complex business protocol |
| Modules are independently deployed | HTTP/gRPC or broker Adapter | Network reliability, versioning, and observability |

Cross-module MediatR requests are not recommended as a way to hide dependency: the consumer still depends on provider request types and the boundary can become a runtime service locator. Default localhost HTTP is also not recommended inside one ApiHost; an interface call is already an in-process API.

## 8. DI and implementation loading

Contracts neither reference Application nor load implementations. A provider Application implements its own Contract, and provider Composition registers the mapping:

```text
A.Contracts interface
  ← implemented by A.Application Facade
  ← registered by A.Composition
  ← loaded when ApiHost calls AddModuleA
```

The consumer Adapter references only provider Contracts. At runtime, the shared DI container resolves the Contract to the Application facade registered by the provider module.

If ApiHost omits a required provider module, container validation or explicit module-dependency validation should fail fast instead of producing an ambiguous error on the first business request.

## 9. Microservice extraction

The target does not require a shared Application or Domain package. When a module becomes a separate service:

- the consumer Application Port remains unchanged;
- the in-process Adapter becomes an HTTP/gRPC Adapter;
- provider Presentation exposes a network API backed by the same Application use case;
- Integration Event schemas become versioned wire contracts; and
- each service owns its DI container, database, and deployment lifecycle.

A very small versioned Contract package may be shared, or clients may be generated from OpenAPI/Proto. Either approach must allow backward compatibility and independent deployment; Domain and Application implementation assemblies must not be shared.

## 10. Suggested order for later planning

This document is not an implementation plan, but later plans should respect the following dependency order:

1. Agree terminology, Contract ownership, and LayerGuard rules.
2. Inventory real consumers and remove or internalize unused Reader methods and DTOs.
3. Correct tenant, authorization, and error semantics on every public Contract.
4. Add provider Application facades so Readers no longer own business decisions directly.
5. Define consumer-owned ports in Transaction and other consumers.
6. Add in-process adapters under Infrastructure/Integrations and remove foreign module references from consumer Application projects.
7. Move external event handlers to inbound Integration Adapters that issue internal commands.
8. Design and implement Outbox, Inbox, idempotency, retry, dead-letter, tracing, and replay.
9. Design complete event and rebuild mechanisms separately for every required local projection.
10. Add architecture tests, contract compatibility tests, and cross-module failure tests.

Every step should leave the system buildable and testable. Contract refactoring and messaging reliability should not become one unreviewable, all-at-once change.

## 11. Common misconceptions to avoid

- Contracts are definitions, not runtime services, and do not locate implementations.
- ApiHost aggregates DI registrations; it does not implement module business behavior.
- Composition is startup wiring, not a business execution step on every request.
- Integration Adapter is an outer adapter, not a new business layer.
- An in-process call is already an API; HTTP is not required for module independence.
- A synchronous read does not create cross-module atomic consistency.
- An Event is not automatically reliable messaging; reliability comes from Outbox, Inbox, idempotency, retries, and operational controls.

