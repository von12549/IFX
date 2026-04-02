# Plan: Fund Registry System — CRM, Registry, Holdings, Transaction

**Status:** Done

---

## Overview

Introduces the core business domain of the Fund Registry System across four new modules: **CRM** (Parties and Investors), **Registry** (Funds and Classes), **Holdings** (unit balances per investor/class), and **Transaction** (subscriptions, redemptions, transfers, switches). A new **Platform.Messaging** service provides the integration event bus that decouples modules from each other (Option B cross-module communication). All modules are tenant-scoped, follow the existing 5-layer Clean Architecture + CQRS pattern, and integrate with the existing RBAC/ABAC authorization model.

---

## Goals

- Deliver Party + Investor management (CRM) with KYC tracking and many-to-many relationship
- Deliver Fund + Class management (Registry) with NAV frequency, fee structures, and lifecycle status
- Deliver Holdings as the source-of-truth unit register (updated via integration events, never directly)
- Deliver Transaction processing for subscriptions, redemptions, transfers, and switches
- Establish Platform.Messaging as the in-process integration event bus with a provider-swappable design
- Each module exposes an `.Abstractions` project so consumers never take a direct module dependency
- All entities tenant-scoped; list endpoints use `ICurrentUser.TenantId` via `X-Tenant-Id` header
- ABAC policies (SameTenant + IsActive templates) seeded per module

---

## Non-Goals

- NAV pricing engine or NAV calculation (future module)
- Reporting / statement generation (future module)
- Document management or KYC document upload
- Real-time messaging / WebSockets
- External message broker integration (RabbitMQ, Service Bus) — in-memory bus only for now
- Frontend UI for any of these modules (separate plan)
- Regulatory reporting

---

## Architecture

### New Projects (26 total)

```
src/
├── Platform/
│   └── Messaging/
│       ├── IFX.Platform.Messaging.Abstractions/        (bus + handler interfaces)
│       ├── IFX.Platform.Messaging.Infrastructure.InMemory/  (in-process dispatch)
│       └── IFX.Platform.Messaging.Composition/         (DI registration)
│
└── Modules/
    ├── CRM/
    │   ├── IFX.Modules.CRM.Abstractions/               (ICrmReader, integration events)
    │   ├── IFX.Modules.CRM.Domain/
    │   ├── IFX.Modules.CRM.Application/
    │   ├── IFX.Modules.CRM.Infrastructure/
    │   ├── IFX.Modules.CRM.Presentation/
    │   └── IFX.Modules.CRM.Composition/
    ├── Registry/
    │   ├── IFX.Modules.Registry.Abstractions/          (IRegistryReader, integration events)
    │   ├── IFX.Modules.Registry.Domain/
    │   ├── IFX.Modules.Registry.Application/
    │   ├── IFX.Modules.Registry.Infrastructure/
    │   ├── IFX.Modules.Registry.Presentation/
    │   └── IFX.Modules.Registry.Composition/
    ├── Holdings/
    │   ├── IFX.Modules.Holdings.Abstractions/          (IHoldingsReader, integration events)
    │   ├── IFX.Modules.Holdings.Domain/
    │   ├── IFX.Modules.Holdings.Application/
    │   ├── IFX.Modules.Holdings.Infrastructure/
    │   ├── IFX.Modules.Holdings.Presentation/
    │   └── IFX.Modules.Holdings.Composition/
    └── Transaction/
        ├── IFX.Modules.Transaction.Abstractions/       (ITransactionReader, integration events)
        ├── IFX.Modules.Transaction.Domain/
        ├── IFX.Modules.Transaction.Application/
        ├── IFX.Modules.Transaction.Infrastructure/
        ├── IFX.Modules.Transaction.Presentation/
        └── IFX.Modules.Transaction.Composition/
```

---

### Dependency Graph

```
Transaction.Application
  → CRM.Abstractions          (ICrmReader — validate investor KYC, party existence)
  → Registry.Abstractions     (IRegistryReader — validate class is active/open)
  → Platform.Messaging.Abstractions  (IIntegrationEventBus — publish TransactionProcessed)

Holdings.Application
  → CRM.Abstractions          (IIntegrationEventHandler<InvestorCreatedEvent>)
  → Transaction.Abstractions  (IIntegrationEventHandler<TransactionProcessedEvent>)
  → Registry.Abstractions     (IIntegrationEventHandler<ClassClosedEvent>)
  → Platform.Messaging.Abstractions  (subscribe to events)

CRM/Registry/Transaction/Holdings.Application
  → Platform.Messaging.Abstractions  (publish integration events)
  → IFX.BuildingBlocks.Security      (ICurrentUser, IResourceAuthorizationService)

No module references another module's Domain, Application, Infrastructure, or Presentation.
```

---

### Platform.Messaging Design

```csharp
// IFX.Platform.Messaging.Abstractions

public interface IIntegrationEvent
{
    Guid EventId { get; }
    DateTime OccurredAt { get; }
}

public interface IIntegrationEventBus
{
    Task PublishAsync<TEvent>(TEvent @event, CancellationToken ct = default)
        where TEvent : IIntegrationEvent;
}

public interface IIntegrationEventHandler<TEvent>
    where TEvent : IIntegrationEvent
{
    Task HandleAsync(TEvent @event, CancellationToken ct = default);
}
```

`InMemoryIntegrationEventBus` resolves all `IIntegrationEventHandler<TEvent>` from the DI container and dispatches sequentially (same thread, same transaction scope). No external broker. Swapping to RabbitMQ/Service Bus later = new `Infrastructure.{Provider}` project + config change.

---

### Domain Entities

#### CRM Module

```
Party (Tenant-scoped)
  PartyId            Guid (UUID v7)
  TenantId           Guid (FK, required)
  PartyCode          string (unique within tenant)
  Name               string
  PartyType          Enum: FundManager | Distributor | Custodian | TransferAgent | Other
  Status             Enum: Active | Suspended | Closed
  CreatedAt          DateTimeOffset
  UpdatedAt          DateTimeOffset

Investor (Tenant-scoped)
  InvestorId         Guid (UUID v7)
  TenantId           Guid (FK, required)
  InvestorCode       string (unique within tenant)
  Name               string
  InvestorType       Enum: Individual | Corporate | Institutional
  KycStatus          Enum: Pending | Approved | Rejected | Expired
  KycReviewedAt      DateTimeOffset? (nullable)
  ResidencyCountry   string (ISO 3166-1 alpha-2)
  TaxResidency       string (ISO 3166-1 alpha-2)
  Status             Enum: Active | Suspended | Closed
  CreatedAt          DateTimeOffset
  UpdatedAt          DateTimeOffset

PartyInvestorRelationship (junction, Tenant-scoped)
  PartyId            Guid (FK)
  InvestorId         Guid (FK)
  RelationshipType   Enum: NomineeShareholder | BeneficialOwner | Distributor | Custodian
  EffectiveDate      DateOnly
  ExpiryDate         DateOnly? (null = open-ended)
  PK: (PartyId, InvestorId, RelationshipType)
```

#### Registry Module

```
Fund (Tenant-scoped)
  FundId             Guid (UUID v7)
  TenantId           Guid (FK, required)
  FundCode           string (unique within tenant)
  FundName           string
  FundType           Enum: UCITS | AIF | Hedge | ETF | PrivateEquity | Other
  BaseCurrency       string (ISO 4217, e.g. USD)
  InceptionDate      DateOnly
  Status             Enum: Active | Closed | Liquidating
  CreatedAt          DateTimeOffset
  UpdatedAt          DateTimeOffset

FundClass (Tenant-scoped, belongs to Fund)
  ClassId            Guid (UUID v7)
  FundId             Guid (FK, required)
  TenantId           Guid (denormalized for tenant filtering)
  ClassCode          string (unique within Fund)
  ClassName          string
  Currency           string (ISO 4217)
  MinInitialInvestment  decimal?
  ManagementFeeRate  decimal? (percentage, e.g. 1.50)
  PerformanceFeeRate decimal?
  NAVFrequency       Enum: Daily | Weekly | Monthly | Quarterly
  Status             Enum: Active | SoftClosed | Closed | Liquidating
  CreatedAt          DateTimeOffset
  UpdatedAt          DateTimeOffset
```

#### Holdings Module

```
Holding (Tenant-scoped)
  HoldingId          Guid (UUID v7)
  TenantId           Guid (FK, required)
  InvestorId         Guid (reference to CRM — no FK across modules)
  ClassId            Guid (reference to Registry — no FK across modules)
  Units              decimal (running balance; 0 = fully redeemed but record kept)
  Status             Enum: Active | Frozen | Closed
  LastTransactionAt  DateTimeOffset?
  CreatedAt          DateTimeOffset
  UpdatedAt          DateTimeOffset
  UNIQUE (TenantId, InvestorId, ClassId)
```

No FK constraints across module boundaries. Referential integrity enforced at the Application layer via `ICrmReader` / `IRegistryReader` lookups before writing.

#### Transaction Module

```
Transaction (Tenant-scoped)
  TransactionId      Guid (UUID v7)
  TenantId           Guid (FK, required)
  TransactionType    Enum: Subscription | Redemption | Transfer | Switch
  PartyId            Guid (reference to CRM)
  InvestorId         Guid (reference to CRM)
  FundId             Guid (reference to Registry)
  ClassId            Guid (reference to Registry — source class for Transfer/Switch)
  TargetClassId      Guid? (reference to Registry — destination class for Switch)
  Amount             decimal
  Units              decimal?   (calculated or provided)
  NAVPrice           decimal?   (price per unit at trade date)
  TradeDate          DateOnly
  SettlementDate     DateOnly?
  Status             Enum: Pending | Processing | Processed | Settled | Cancelled | Failed
  FailureReason      string?
  CreatedAt          DateTimeOffset
  UpdatedAt          DateTimeOffset
```

---

### Integration Events (per-module, in `.Abstractions`)

```
CRM.Abstractions/Events/
  PartyCreatedEvent          (PartyId, TenantId, PartyCode, Name)
  PartyStatusChangedEvent    (PartyId, TenantId, OldStatus, NewStatus)
  InvestorCreatedEvent       (InvestorId, TenantId, InvestorCode, Name)
  InvestorKycStatusChangedEvent (InvestorId, TenantId, OldStatus, NewStatus)

Registry.Abstractions/Events/
  FundCreatedEvent           (FundId, TenantId, FundCode, FundName)
  FundStatusChangedEvent     (FundId, TenantId, OldStatus, NewStatus)
  ClassCreatedEvent          (ClassId, FundId, TenantId, ClassCode)
  ClassStatusChangedEvent    (ClassId, FundId, TenantId, OldStatus, NewStatus)

Transaction.Abstractions/Events/
  TransactionCreatedEvent    (TransactionId, TenantId, TransactionType, InvestorId, ClassId, Amount)
  TransactionProcessedEvent  (TransactionId, TenantId, TransactionType, InvestorId, ClassId, Units, NAVPrice)
  TransactionSettledEvent    (TransactionId, TenantId)
  TransactionCancelledEvent  (TransactionId, TenantId)

Holdings.Abstractions/Events/
  HoldingFrozenEvent         (HoldingId, TenantId, ClassId, InvestorId)
```

**Who subscribes to what:**

| Event | Subscriber | Action |
|-------|-----------|--------|
| `TransactionProcessedEvent` | Holdings | Upsert holding, adjust units +/- |
| `ClassStatusChangedEvent` (→Closed) | Holdings | Freeze all holdings in that class |
| `InvestorKycStatusChangedEvent` (→Rejected) | Transaction | Flag pending transactions for review (future) |

---

### ABAC Permissions per Module

```
CRM:
  Party:list, Party:read, Party:create, Party:update, Party:delete
  Investor:list, Investor:read, Investor:create, Investor:update, Investor:delete
  PartyInvestor:link, PartyInvestor:unlink

Registry:
  Fund:list, Fund:read, Fund:create, Fund:update, Fund:delete
  Class:list, Class:read, Class:create, Class:update, Class:delete

Holdings:
  Holding:list, Holding:read

Transaction:
  Transaction:list, Transaction:read, Transaction:create, Transaction:process, Transaction:cancel
```

All resource types use `SameTenant` + `IsActive` condition templates. `PolicyDefinition` seed rows inserted via EF migration (platform-level, `TenantId = NULL`) for each resource type.

---

### API Endpoints

**CRM — Parties** (`X-Tenant-Id` required)
```
GET    /api/v1/party              → GetPartiesQuery
GET    /api/v1/party/{id}         → GetPartyByIdQuery
POST   /api/v1/party              → CreatePartyCommand
PUT    /api/v1/party/{id}         → UpdatePartyCommand
DELETE /api/v1/party/{id}         → DeletePartyCommand
GET    /api/v1/party/{id}/investors → GetInvestorsByPartyQuery
POST   /api/v1/party/{id}/investors/{investorId} → LinkInvestorToPartyCommand
DELETE /api/v1/party/{id}/investors/{investorId} → UnlinkInvestorFromPartyCommand
```

**CRM — Investors** (`X-Tenant-Id` required)
```
GET    /api/v1/investor           → GetInvestorsQuery
GET    /api/v1/investor/{id}      → GetInvestorByIdQuery
POST   /api/v1/investor           → CreateInvestorCommand
PUT    /api/v1/investor/{id}      → UpdateInvestorCommand
DELETE /api/v1/investor/{id}      → DeleteInvestorCommand
PUT    /api/v1/investor/{id}/kyc  → UpdateInvestorKycCommand
```

**Registry — Funds** (`X-Tenant-Id` required)
```
GET    /api/v1/fund               → GetFundsQuery
GET    /api/v1/fund/{id}          → GetFundByIdQuery
POST   /api/v1/fund               → CreateFundCommand
PUT    /api/v1/fund/{id}          → UpdateFundCommand
DELETE /api/v1/fund/{id}          → DeleteFundCommand
```

**Registry — Classes** (`X-Tenant-Id` required)
```
GET    /api/v1/fund/{fundId}/class           → GetClassesQuery
GET    /api/v1/fund/{fundId}/class/{id}      → GetClassByIdQuery
POST   /api/v1/fund/{fundId}/class           → CreateClassCommand
PUT    /api/v1/fund/{fundId}/class/{id}      → UpdateClassCommand
DELETE /api/v1/fund/{fundId}/class/{id}      → DeleteClassCommand
```

**Holdings** (`X-Tenant-Id` required, read-only)
```
GET    /api/v1/holding                       → GetHoldingsQuery
GET    /api/v1/holding/{id}                  → GetHoldingByIdQuery
GET    /api/v1/investor/{investorId}/holdings → GetHoldingsByInvestorQuery
GET    /api/v1/fund/{fundId}/class/{classId}/holdings → GetHoldingsByClassQuery
```

**Transactions** (`X-Tenant-Id` required)
```
GET    /api/v1/transaction              → GetTransactionsQuery
GET    /api/v1/transaction/{id}         → GetTransactionByIdQuery
POST   /api/v1/transaction/subscription → CreateSubscriptionCommand
POST   /api/v1/transaction/redemption   → CreateRedemptionCommand
POST   /api/v1/transaction/transfer     → CreateTransferCommand
POST   /api/v1/transaction/switch       → CreateSwitchCommand
POST   /api/v1/transaction/{id}/process → ProcessTransactionCommand
POST   /api/v1/transaction/{id}/cancel  → CancelTransactionCommand
```

---

## Implementation Steps

### Phase 0 — Platform.Messaging

- [ ] Create `src/Platform/Messaging/` directory structure (3 projects)
- [ ] Define `IIntegrationEvent` base record with `EventId` (UUID v7) and `OccurredAt`
- [ ] Define `IIntegrationEventBus` with `PublishAsync<TEvent>`
- [ ] Define `IIntegrationEventHandler<TEvent>` with `HandleAsync`
- [ ] Implement `InMemoryIntegrationEventBus` (resolves handlers from `IServiceProvider`, dispatches sequentially)
- [ ] Implement `MessagingServiceCollectionExtensions.AddMessaging()` — registers bus + auto-discovers all `IIntegrationEventHandler<>` implementations via assembly scanning
- [ ] Add `Platform.Messaging.Abstractions` and `Platform.Messaging.Infrastructure.InMemory` to `IFX.sln`
- [ ] Wire `AddMessaging()` in `Program.cs`
- [ ] Write unit tests for `InMemoryIntegrationEventBus` (publish dispatches to all handlers, exceptions in one handler don't skip others)

### Phase 1 — CRM Module

**Domain**
- [ ] Create `IFX.Modules.CRM.Domain` project
- [ ] Define `Party` entity with factory method `Party.Create(tenantId, code, name, type)`
- [ ] Define `Investor` entity with factory method `Investor.Create(tenantId, code, name, type, country, taxResidency)`
- [ ] Define `PartyInvestorRelationship` entity with `Link` / `Unlink` factory methods
- [ ] Define domain events: `PartyCreatedDomainEvent`, `InvestorCreatedDomainEvent`, `InvestorKycStatusChangedDomainEvent`
- [ ] Define repository interfaces: `IPartyRepository`, `IInvestorRepository`, `IPartyInvestorRepository`
- [ ] Define `ICrmUnitOfWork` interface

**Abstractions**
- [ ] Create `IFX.Modules.CRM.Abstractions` project (references `Platform.Messaging.Abstractions`)
- [ ] Define `ICrmReader` with `GetPartyByIdAsync`, `GetInvestorByIdAsync`, `IsInvestorKycApprovedAsync`
- [ ] Define `PartyCreatedEvent`, `PartyStatusChangedEvent`, `InvestorCreatedEvent`, `InvestorKycStatusChangedEvent` (all `: IIntegrationEvent`)
- [ ] Define lightweight summary DTOs: `PartySummaryDto`, `InvestorSummaryDto`

**Application**
- [ ] Create `IFX.Modules.CRM.Application` project
- [ ] Commands: `CreatePartyCommand`, `UpdatePartyCommand`, `DeletePartyCommand`
- [ ] Commands: `CreateInvestorCommand`, `UpdateInvestorCommand`, `UpdateInvestorKycCommand`, `DeleteInvestorCommand`
- [ ] Commands: `LinkInvestorToPartyCommand`, `UnlinkInvestorFromPartyCommand`
- [ ] Queries: `GetPartiesQuery`, `GetPartyByIdQuery`, `GetInvestorsByPartyQuery`
- [ ] Queries: `GetInvestorsQuery`, `GetInvestorByIdQuery`
- [ ] FluentValidation validators for all commands
- [ ] AutoMapper profiles: `Party → PartyDto`, `Investor → InvestorDto`
- [ ] `CreatePartyCommandHandler` publishes `PartyCreatedEvent` via `IIntegrationEventBus`
- [ ] `UpdateInvestorKycCommandHandler` publishes `InvestorKycStatusChangedEvent`
- [ ] ABAC: register `Party` and `Investor` resource types with `SameTenant` + `IsActive` templates

**Infrastructure**
- [ ] Create `IFX.Modules.CRM.Infrastructure` project
- [ ] `CrmDbContext` with `DbSet<Party>`, `DbSet<Investor>`, `DbSet<PartyInvestorRelationship>`
- [ ] EF entity configurations (unique indexes: `PartyCode` within tenant, `InvestorCode` within tenant)
- [ ] Repository implementations: `EfPartyRepository`, `EfInvestorRepository`, `EfPartyInvestorRepository`
- [ ] `CrmUnitOfWork` implementation
- [ ] `CrmReader` implementation (implements `ICrmReader` from Abstractions)
- [ ] Initial EF migration: `InitialCreate` + `InitialSeed` (PolicyDefinition rows for Party + Investor)
- [ ] `CrmMigrator : IAppMigrator`

**Presentation**
- [ ] Create `IFX.Modules.CRM.Presentation` project
- [ ] Party endpoints (8 endpoints — see API section above)
- [ ] Investor endpoints (6 endpoints)
- [ ] All endpoints behind `RequireAuthorization()` + permission checks

**Composition**
- [ ] Create `IFX.Modules.CRM.Composition` project
- [ ] `CrmModuleInstaller : IModuleInstaller` — registers all layers + exposes `ICrmReader`
- [ ] `AddCrmModule()` extension method
- [ ] Register all `IIntegrationEventHandler<>` implementations from CRM.Application
- [ ] Wire in `Program.cs`

### Phase 2 — Registry Module

**Domain**
- [ ] Create `IFX.Modules.Registry.Domain` project
- [ ] Define `Fund` entity with factory method `Fund.Create(tenantId, code, name, type, currency, inceptionDate)`
- [ ] Define `FundClass` entity with factory method `FundClass.Create(fundId, tenantId, code, name, currency, navFrequency)`
- [ ] Define `FundClass.Close()` method (sets status, raises `FundClassClosedDomainEvent`)
- [ ] Define domain events: `FundCreatedDomainEvent`, `FundClassCreatedDomainEvent`, `FundClassStatusChangedDomainEvent`
- [ ] Define repository interfaces: `IFundRepository`, `IFundClassRepository`
- [ ] Define `IRegistryUnitOfWork`

**Abstractions**
- [ ] Create `IFX.Modules.Registry.Abstractions` project
- [ ] Define `IRegistryReader` with `GetFundByIdAsync`, `GetClassByIdAsync`, `IsClassOpenForSubscriptionAsync`
- [ ] Define `FundCreatedEvent`, `FundStatusChangedEvent`, `ClassCreatedEvent`, `ClassStatusChangedEvent` (`: IIntegrationEvent`)
- [ ] Define `FundSummaryDto`, `ClassSummaryDto`

**Application**
- [ ] Commands: `CreateFundCommand`, `UpdateFundCommand`, `DeleteFundCommand`
- [ ] Commands: `CreateClassCommand`, `UpdateClassCommand`, `DeleteClassCommand`, `CloseClassCommand`
- [ ] Queries: `GetFundsQuery`, `GetFundByIdQuery`, `GetClassesQuery`, `GetClassByIdQuery`
- [ ] FluentValidation validators for all commands
- [ ] AutoMapper profiles
- [ ] `CloseClassCommandHandler` publishes `ClassStatusChangedEvent` (Status = Closed)
- [ ] ABAC: `Fund` + `FundClass` resource types with `SameTenant` + `IsActive` templates

**Infrastructure**
- [ ] `RegistryDbContext` with `DbSet<Fund>`, `DbSet<FundClass>`
- [ ] EF configurations (unique: `FundCode` within tenant; `ClassCode` within fund)
- [ ] Repository implementations + `RegistryUnitOfWork`
- [ ] `RegistryReader` (implements `IRegistryReader`)
- [ ] Initial migration + seed PolicyDefinition rows for Fund + FundClass
- [ ] `RegistryMigrator : IAppMigrator`

**Presentation**
- [ ] Fund endpoints (5 endpoints)
- [ ] Class endpoints (5 endpoints, nested under `/fund/{fundId}/class`)

**Composition**
- [ ] `RegistryModuleInstaller`, `AddRegistryModule()`, wire in `Program.cs`

### Phase 3 — Holdings Module

**Domain**
- [ ] Create `IFX.Modules.Holdings.Domain` project
- [ ] Define `Holding` entity with:
  - `Holding.Create(tenantId, investorId, classId)` — creates with zero units
  - `Holding.ApplySubscription(units)` — adds units
  - `Holding.ApplyRedemption(units)` — subtracts units (throws if units < 0)
  - `Holding.Freeze()` / `Holding.Unfreeze()` — status changes
- [ ] Define domain events: `HoldingCreatedDomainEvent`, `HoldingFrozenDomainEvent`
- [ ] Define `IHoldingRepository`
- [ ] Define `IHoldingsUnitOfWork`

**Abstractions**
- [ ] Create `IFX.Modules.Holdings.Abstractions` project
- [ ] Define `IHoldingsReader` with `GetHoldingsByInvestorAsync`, `GetHoldingsByClassAsync`, `GetHoldingByIdAsync`
- [ ] Define `HoldingFrozenEvent` (`: IIntegrationEvent`)
- [ ] Define `HoldingSummaryDto`

**Application**
- [ ] Commands: none directly from HTTP — holdings mutated only by integration events
- [ ] Internal command: `ApplyTransactionToHoldingCommand` (triggered by `TransactionProcessedEvent` handler)
- [ ] Internal command: `FreezeHoldingsByClassCommand` (triggered by `ClassStatusChangedEvent` handler)
- [ ] Integration event handlers:
  - `TransactionProcessedEventHandler` → dispatches `ApplyTransactionToHoldingCommand`
  - `ClassStatusChangedEventHandler` (Status = Closed | Liquidating) → dispatches `FreezeHoldingsByClassCommand`
- [ ] Queries: `GetHoldingsQuery`, `GetHoldingByIdQuery`, `GetHoldingsByInvestorQuery`, `GetHoldingsByClassQuery`
- [ ] ABAC: `Holding` resource with `SameTenant` template (read-only for most users)

**Infrastructure**
- [ ] `HoldingsDbContext` with `DbSet<Holding>`
- [ ] EF configuration (unique index: `TenantId + InvestorId + ClassId`)
- [ ] `EfHoldingRepository` + `HoldingsUnitOfWork`
- [ ] `HoldingsReader` (implements `IHoldingsReader`)
- [ ] Initial migration + seed PolicyDefinition rows for Holding
- [ ] `HoldingsMigrator : IAppMigrator`

**Presentation**
- [ ] 4 read-only GET endpoints (no write endpoints exposed via HTTP)

**Composition**
- [ ] `HoldingsModuleInstaller` — registers event handlers from Application
- [ ] `AddHoldingsModule()`, wire in `Program.cs`

### Phase 4 — Transaction Module

**Domain**
- [ ] Create `IFX.Modules.Transaction.Domain` project
- [ ] Define `Transaction` entity with:
  - `Transaction.CreateSubscription(tenantId, partyId, investorId, fundId, classId, amount, tradeDate)`
  - `Transaction.CreateRedemption(...)` — same shape
  - `Transaction.CreateTransfer(...)` — same + targetClassId
  - `Transaction.CreateSwitch(...)` — same
  - `Transaction.Process(units, navPrice)` — sets status to Processed, raises domain event
  - `Transaction.Cancel(reason)` — sets status to Cancelled
  - `Transaction.Fail(reason)` — sets status to Failed
- [ ] Define domain events: `TransactionCreatedDomainEvent`, `TransactionProcessedDomainEvent`, `TransactionCancelledDomainEvent`
- [ ] Define `ITransactionRepository`
- [ ] Define `ITransactionUnitOfWork`

**Abstractions**
- [ ] Create `IFX.Modules.Transaction.Abstractions` project
- [ ] Define `ITransactionReader` with `GetTransactionsByInvestorAsync`, `GetTransactionByIdAsync`
- [ ] Define `TransactionCreatedEvent`, `TransactionProcessedEvent`, `TransactionSettledEvent`, `TransactionCancelledEvent` (`: IIntegrationEvent`)
- [ ] Define `TransactionSummaryDto`

**Application**
- [ ] Commands: `CreateSubscriptionCommand`, `CreateRedemptionCommand`, `CreateTransferCommand`, `CreateSwitchCommand`
- [ ] Commands: `ProcessTransactionCommand`, `CancelTransactionCommand`
- [ ] Queries: `GetTransactionsQuery`, `GetTransactionByIdQuery`
- [ ] FluentValidation validators — all creation commands call `ICrmReader.IsInvestorKycApprovedAsync` + `IRegistryReader.IsClassOpenForSubscriptionAsync`
- [ ] `CreateSubscriptionCommandHandler` → creates Transaction → publishes `TransactionCreatedEvent`
- [ ] `ProcessTransactionCommandHandler` → processes Transaction → publishes `TransactionProcessedEvent`
- [ ] ABAC: `Transaction` resource with `SameTenant` + `IsActive` templates
- [ ] Inject `ICrmReader` + `IRegistryReader` into command validators (cross-module lookup via Abstractions only)

**Infrastructure**
- [ ] `TransactionDbContext` with `DbSet<Transaction>`
- [ ] EF configuration
- [ ] `EfTransactionRepository` + `TransactionUnitOfWork`
- [ ] `TransactionReader` (implements `ITransactionReader`)
- [ ] Initial migration + seed PolicyDefinition rows for Transaction
- [ ] `TransactionMigrator : IAppMigrator`

**Presentation**
- [ ] 2 GET endpoints + 6 POST endpoints (see API section)

**Composition**
- [ ] `TransactionModuleInstaller`
- [ ] `AddTransactionModule()`, wire in `Program.cs`

### Phase 5 — Decisions & Docs

- [ ] Add `ADR-011: Integration Event Bus (Platform.Messaging)` to `.claude/decisions.md`
- [ ] Add `ADR-012: Fund Registry Domain Modules` to `.claude/decisions.md`
- [ ] Update `CLAUDE.md` Quick Reference with new API endpoints
- [ ] Update `CLAUDE.md` Instruction Index with this plan file
- [ ] Update `/.claude/architecture.md` with multi-module dependency graph

---

## Testing Plan

### Unit Tests (per module, mirror `tests/` structure)

- `Party.Create` / `Investor.Create` — validates required fields and enum constraints
- `Holding.ApplyRedemption` — throws when units go negative
- `FundClass.Close()` — sets status, raises domain event
- `Transaction.Process` / `Transaction.Cancel` — state machine transitions
- `InMemoryIntegrationEventBus` — dispatches to all handlers, exception isolation
- All command validators — required fields, cross-field rules (e.g., TargetClassId required for Switch)
- `CrmReader.IsInvestorKycApprovedAsync` — approved/non-approved scenarios

### Integration Tests

- `POST /api/v1/party` → party created, `PartyCreatedEvent` published, handler invoked
- `POST /api/v1/investor` with missing KYC fields → 400
- `POST /api/v1/transaction/subscription` with KYC-rejected investor → 422 Unprocessable
- `POST /api/v1/transaction/subscription` with closed class → 422 Unprocessable
- `POST /api/v1/transaction/{id}/process` → holding upserted, units incremented
- `POST /api/v1/fund/{fundId}/class/{id}/close` (via status update) → holdings frozen
- ABAC: `Party:create` denied for user without permission → 403
- ABAC: `Party:read` denied cross-tenant → 403
- Tenant isolation: Party list for Tenant A does not include Tenant B parties

### Manual Verification

- Create a Party, create an Investor, link them with RelationshipType = Distributor
- Create a Fund, create a Class (Active, Daily NAV)
- Create a Subscription transaction; verify it starts in Pending
- Process the transaction; verify Holding is created with correct units
- Close the Class; verify all holdings for that class are Frozen
- Attempt subscription to Closed class; verify rejection

---

## Open Questions

~~1. **Transaction Units calculation** — is `Units = Amount / NAVPrice` done in the `ProcessTransactionCommand`, or does the caller provide both?~~
**Resolved:** Caller provides `NAVPrice`; system calculates `Units = Amount / NAVPrice` inside `ProcessTransactionCommand`.

~~2. **Partial redemption** — can a redemption be for fewer units than the total holding?~~
**Resolved:** Yes — redemption amount may be partial. Holding balance decremented by the calculated units only.

~~3. **Holding on Transfer** — one Transaction or two?~~
**Resolved:** One `Transaction` with `TargetClassId`. `TransactionProcessedEventHandler` in Holdings performs the two-sided update: decrement source class holding, increment target class holding (upsert if no holding exists yet).

~~4. **Cross-tenant Party/Investor** — shared across tenants?~~
**Resolved:** No. Party and Investor are strictly tenant-scoped. No cross-tenant sharing.

~~5. **Soft delete vs status change** — hard delete or Status = Closed?~~
**Resolved:** Soft-delete — `DeletePartyCommand`, `DeleteInvestorCommand`, `DeleteFundCommand`, `DeleteClassCommand` all set `Status = Closed`. No rows are hard-deleted. ABAC `IsActive` template enforces that closed entities are read-only.

---

## Status History

| Date | Status | Notes |
|------|--------|-------|
| 2026-04-01 | Plan | Plan created |
| 2026-04-02 | Implementing | Phases 0–4 complete (Platform.Messaging, CRM, Registry, Holdings, Transaction) |
| 2026-04-02 | Done | Phase 5 docs complete; all modules implemented and committed |
