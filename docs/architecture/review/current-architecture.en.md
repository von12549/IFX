# Current IFX module architecture

> Document status: current-state baseline  
> Source baseline: `308d548`  
> This document describes implemented behavior, not the proposed target.

## 1. Overall assessment

IFX is currently an ASP.NET Core 8 modular monolith, not a microservice system. One ApiHost process loads every business module, while separate projects, DbContexts, and SQL schemas provide module boundaries.

The business modules are Auth, CRM, Registry, Holdings, and Transaction. Platform capabilities include Messaging, BackgroundJobs, and Notifications. ApiHost explicitly calls each `Add*Module` method and later enumerates `IModuleInstaller` registrations to map endpoints.

Related diagrams:

- [Current architecture](diagrams/01-current-architecture.md)
- [Current communication flows](diagrams/02-current-communication-flows.md)

## 2. Four distinct boundaries

### 2.1 Compile-time boundary

A business module normally contains Domain, Application, Infrastructure, Presentation, and Composition projects. CRM, Registry, Holdings, and Transaction also contain an Abstractions project.

Cross-module code is intended to reference another module's Abstractions only, never its Domain, Application, Infrastructure, or Presentation. The main current relationships are:

- Transaction.Application references CRM.Abstractions and Registry.Abstractions.
- Holdings.Application references Transaction.Abstractions and Registry.Abstractions.
- Module Application projects reference Platform.Messaging.Abstractions to publish events.
- Each Composition project references its module layers so ApiHost can load the module.

The solution therefore has useful compile-time isolation, although consumer Application projects still know provider contract types directly.

### 2.2 Database boundary

Auth, CRM, Registry, Holdings, and Transaction each own a DbContext, EF migrations, and SQL schema. Docker normally hosts those schemas in the same `IFXDb` database; Hangfire uses a separate database.

A shared physical database does not imply shared data ownership. A module should not query or update another module's DbContext or tables, and business foreign keys should not cross module schemas. Application workflows, synchronous contract queries, and event workflows enforce cross-module references.

### 2.3 Transaction boundary

Module DbContexts do not participate in one atomic business transaction. Although they may connect to the same SQL Server database, the current code does not atomically commit a producer module transaction and a consumer module transaction.

A synchronous read also does not create cross-module atomicity. CRM state may change after Transaction checks KYC and before Transaction commits. This is a check-then-act race; replacing the in-process call with HTTP would not solve it.

### 2.4 Deployment boundary

All modules are deployed through one ApiHost. They cannot currently scale, release, or fail independently. `IModuleInstaller` standardizes module assembly and endpoint mapping, but it is not dynamic runtime plugin discovery because Program.cs still registers every module explicitly.

## 3. Current Abstractions responsibilities

Module Abstractions projects currently contain three categories:

1. Synchronous cross-module readers such as `ICrmReader` and `IRegistryReader`.
2. Cross-module DTOs such as `PartySummaryDto`, `ClassSummaryDto`, and `HoldingSummaryDto`.
3. Integration Events such as `TransactionProcessedEvent` and `ClassStatusChangedEvent`.

By intent, Abstractions is the module's public communication contract, not a fifth business ring in Clean Architecture. These public contracts are different from repositories, units of work, and external service ports used internally by Application.

## 4. Current synchronous communication

When Transaction creates an order or transaction, it uses `ICrmReader` to check investment-account KYC and `IRegistryReader` to check whether a Fund Class is open for subscription.

The runtime path is:

```text
Transaction.Application
  → CRM/Registry Abstractions interface
  → CRM/Registry Infrastructure Reader
  → provider DbContext
```

This approach is simple and low latency, and the consumer does not reference provider implementation projects.

Its current weaknesses are:

- Reader implementations use DbContext directly and bypass a provider Application facade.
- `IsInvestmentAccountKycApprovedAsync` aggregates account relationships and KYC state, which is more than mechanical data access.
- `ICrmReader` and `IRegistryReader` expose more operations than current production consumers require.
- `IHoldingsReader` and `ITransactionReader` have no production cross-module consumers and are speculative public APIs.
- `Task<bool>` cannot distinguish NotApproved, NotFound, Denied, Timeout, and Unavailable.
- `ITransactionReader.GetTransactionByIdAsync`, `GetOrderByIdAsync`, and `IHoldingsReader.GetHoldingByIdAsync` do not require tenantId, creating a potential tenant-boundary bypass if consumed publicly.

## 5. Current event communication

Application handlers publish Integration Events through `IIntegrationEventBus` after saving producer state. The current `InMemoryIntegrationEventBus` resolves all handlers in the same process and invokes them sequentially and synchronously.

A representative path is:

```text
Transaction.Application
  → TransactionProcessedEvent
  → InMemoryIntegrationEventBus
  → Holdings.Application EventHandler
  → Holdings DbContext
```

Important current risks are:

- An event is handled before the producer transaction commits.
- Holdings saves through its own DbContext and does not share the Transaction atomic boundary.
- The bus logs and swallows consumer exceptions.
- Transaction can commit while Holdings fails.
- Holdings can also save first and the later Transaction commit can fail.
- There is no durable Outbox, Inbox, retry schedule, dead-letter handling, or idempotent consumption record.
- TransactionBehavior rolls back only on exceptions and does not inspect `Result.IsSuccess`; a handler that catches an exception and returns Failure still leads to a commit.

## 6. Can current events replace synchronous reads?

Not directly. Event Notification means that something happened; it does not answer the current-state question. A consumer can avoid synchronous queries only after subscribing to a complete event stream and maintaining a local projection.

The current CRM events are insufficient to reconstruct investment-account KYC. Investor KYC events do not contain account associations, InvestmentAccountCreated does not contain Party/Investor associations, and not every account-link change has an Integration Event. Registry Class state is simpler to project, but the current bus still lacks reliable delivery and rebuild capabilities.

## 7. Architecture rule drift

The retired `src/layerguard.json` policy used a broad `X-1` rule that forbade every ring from referencing its own `.Abstractions` project. At the time, CRM, Registry, Holdings, and Transaction Application projects still referenced their own Abstractions for events or DTOs.

The rule and implementation are therefore inconsistent. Removing references mechanically would not resolve the design question; the team must first decide whether Abstractions is a public Contracts assembly or an internal ring. The target proposal defines it as public Contracts and replaces the blanket prohibition with precise ownership rules.

## 8. Current-state conclusion

The current direction is broadly healthy: cross-module dependencies are restricted to public contract assemblies and database ownership is mostly explicit. The main issues are not the existence of Abstractions but:

- an unnecessarily broad public surface;
- reuse of public DTOs as internal Application DTOs;
- provider business queries implemented in Infrastructure;
- consumer Application projects directly coupled to provider contracts;
- messaging without a reliable delivery boundary; and
- implicit cross-module consistency semantics.

These findings form the starting point for the target Contracts/Adapters/Events architecture.

## 9. Source verification entry points

| Topic | Source |
|---|---|
| ApiHost module loading and endpoint mapping | [`Program.cs`](../../../src/ApiHost/IFX.ApiHost/Program.cs) |
| Transaction project references to CRM/Registry Contracts | [`IFX.Modules.Transaction.Application.csproj`](../../../src/Modules/Transaction/IFX.Modules.Transaction.Application/IFX.Modules.Transaction.Application.csproj) |
| Current synchronous KYC/Class queries | [`CreateOrderCommandHandler.cs`](../../../src/Modules/Transaction/IFX.Modules.Transaction.Application/Commands/CreateOrder/CreateOrderCommandHandler.cs) |
| CRM Reader and direct DbContext access | [`CrmReader.cs`](../../../src/Modules/CRM/IFX.Modules.CRM.Infrastructure/Services/CrmReader.cs) |
| Registry Reader and direct DbContext access | [`RegistryReader.cs`](../../../src/Modules/Registry/IFX.Modules.Registry.Infrastructure/Services/RegistryReader.cs) |
| Transaction save and event publication | [`ProcessTransactionCommandHandler.cs`](../../../src/Modules/Transaction/IFX.Modules.Transaction.Application/Commands/ProcessTransaction/ProcessTransactionCommandHandler.cs) |
| Transaction pipeline transaction | [`TransactionBehavior.cs`](../../../src/Modules/Transaction/IFX.Modules.Transaction.Application/Behaviors/TransactionBehavior.cs) |
| Current synchronous in-memory event bus | [`InMemoryIntegrationEventBus.cs`](../../../src/Platform/Messaging/IFX.Platform.Messaging.Infrastructure.InMemory/InMemoryIntegrationEventBus.cs) |
| Holdings event consumption and persistence | [`TransactionProcessedEventHandler.cs`](../../../src/Modules/Holdings/IFX.Modules.Holdings.Application/EventHandlers/TransactionProcessedEventHandler.cs) |
| Current architecture-check rules | [`V3_ifx policy`](../../guards/V3_ifx/policy/layerguard.json) |
