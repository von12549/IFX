# Advisory: FrankieOne AML/KYC Integration + Event Sourcing for Registry

**Date:** 2026-04-02  
**Status:** For discussion — no implementation started  
**Author:** Architecture review

---

## 1. FrankieOne AML/KYC Integration

### Current State

The CRM module models KYC as a single boolean on `Investor`:

```csharp
public bool IsKycApproved { get; private set; }
public DateTime? KycApprovedAt { get; private set; }
```

`UpdateInvestorKycCommand` sets this manually (operator-driven). The Transaction module gates
subscriptions/redemptions on `ICrmReader.IsInvestorKycApprovedAsync()`.

### What FrankieOne Changes

FrankieOne is a KYC/AML orchestration layer that runs identity verification, document checks,
PEP/sanctions screening, and ongoing monitoring. It is not a simple approve/deny — it returns
a richer result that needs to be modelled properly.

---

### Domain Model Changes

**Replace the boolean with a `KycStatus` enum:**

```csharp
public enum KycStatus
{
    NotStarted,
    Pending,       // submitted to FrankieOne, awaiting result
    Passed,
    Referred,      // manual review required
    Failed,
    Expired        // re-verification needed (e.g. document expiry)
}
```

**Add FrankieOne identity fields to `Investor`:**

```csharp
public string? FrankieEntityId { get; private set; }   // FrankieOne's stable entity ID
public KycStatus KycStatus { get; private set; }
public DateTime? KycCheckedAt { get; private set; }
public string? KycFailReason { get; private set; }
```

**Update the `Transaction` gate:**  
`IsInvestorKycApprovedAsync` should return `true` only when `KycStatus == Passed`. The
`Referred` status might be policy-configurable per tenant (allow redemptions but block new
subscriptions, for example).

---

### Architecture Fit

FrankieOne is an **external identity provider** — it belongs in `CRM.Infrastructure`, not
the domain or application layer.

```
IFX.Modules.CRM.Application
  └── Interfaces/
        └── IKycService.cs          ← new abstraction (Application layer)
              InitiateKycAsync(investorId, ...)
              GetKycStatusAsync(frankieEntityId)

IFX.Modules.CRM.Infrastructure
  └── KYC/
        └── FrankieOneKycService.cs  ← implements IKycService
        └── FrankieOneWebhookHandler.cs
        └── FrankieOneOptions.cs
```

The Application layer only depends on `IKycService` — swapping FrankieOne for another
provider (Jumio, Onfido) is a config change, consistent with the existing pluggable provider
pattern used in Auth.

---

### Webhook / Async Flow

FrankieOne verifications are often asynchronous. The recommended flow:

```
1. POST /api/v1/investor/{id}/kyc/initiate
   → CreateKycCheckCommand → FrankieOneKycService.InitiateAsync()
   → sets KycStatus = Pending, stores FrankieEntityId
   → publishes InvestorKycInitiatedEvent

2. FrankieOne calls POST /api/v1/webhooks/frankie (new endpoint)
   → FrankieOneWebhookController → ProcessKycWebhookCommand
   → updates KycStatus (Passed/Failed/Referred)
   → publishes InvestorKycStatusChangedEvent (already exists)
   → Transaction module reacts if status changed to Failed (e.g. block pending transactions)
```

**Key concern:** the webhook endpoint must be public (no JWT) but protected by a
FrankieOne HMAC signature. Implement signature verification middleware before the endpoint
is merged.

---

### Ongoing Monitoring

FrankieOne can push watchlist-change webhooks long after initial approval. This means
`KycStatus` can transition from `Passed → Failed` at any time. The Transaction module must
re-check KYC at transaction creation time (which it already does), and the Holdings module
may need to freeze holdings when an investor's KYC fails post-approval.

**Suggested integration event chain:**

```
InvestorKycStatusChangedEvent (KycStatus = Failed)
  → Holdings.InvestorKycFailedEventHandler
      → freeze all holdings for that investor
```

This follows the same pattern as `ClassStatusChangedEvent → freeze holdings`.

---

### Open Questions for FrankieOne

1. **Tenant isolation** — does each tenant have their own FrankieOne account, or is there
   one platform account? This affects how `FrankieEntityId` is stored and whether KYC
   results are tenant-scoped.
2. **Re-verification policy** — who triggers re-KYC: the investor, an operator, or FrankieOne
   automatically? Should `KycStatus = Expired` block transactions?
3. **Referred workflow** — does the platform need a case management UI for Referred cases,
   or is this handled in the FrankieOne portal?
4. **Data residency** — FrankieOne stores PII; confirm that is acceptable for all tenants'
   regulatory jurisdictions before integration.

---

## 2. Event Sourcing for the Registry Module

### Why Registry Is a Good Candidate

The Registry (Funds and Classes) is heavily regulated. Auditors need to answer: _"What were
the exact terms of this fund class on 15 March 2024?"_ Traditional CRUD with `UpdatedAt`
cannot answer that. Event sourcing can.

Additionally, NAV pricing (a future module) naturally produces a stream of immutable
`NAVRecordedEvent` facts — event sourcing is the natural fit.

---

### Two Strategies

#### Option A — Full Event Sourcing (Recommended for Registry)

Replace the EF `Fund`/`FundClass` write model with an event stream. The entities become
**aggregates** that rebuild state by replaying events.

```
Events:
  FundCreatedEvent     { FundId, TenantId, Code, Name, Type, Currency, InceptionDate }
  FundUpdatedEvent     { FundId, Name?, Type?, Currency? }
  FundClosedEvent      { FundId }
  ClassCreatedEvent    { ClassId, FundId, Code, Name, Currency, NavFrequency, Fees }
  ClassUpdatedEvent    { ClassId, ... }
  ClassClosedEvent     { ClassId }
  NAVRecordedEvent     { ClassId, NAVDate, NAVPrice, TotalNAV }  ← future
```

Read models (projections) rebuilt from the stream power the existing query endpoints.

#### Option B — Hybrid (Easier Migration Path)

Keep the existing EF write model. Add an `EventLog` table that records every mutation as
an immutable event. The application layer explicitly appends events alongside SaveChanges.

```csharp
// In CreateFundCommandHandler:
await _unitOfWork.Funds.AddAsync(fund);
await _unitOfWork.EventLog.AppendAsync(new FundCreatedEvent(...));
await _unitOfWork.SaveChangesAsync();
```

**Pros:** Low disruption, existing queries unchanged, can migrate to full ES later.  
**Cons:** Dual writes are not atomic without a transaction, projections must be rebuilt
manually, does not give temporal queries out of the box.

**Recommendation:** Start with Option B (hybrid) as a stepping stone. Introduce full event
sourcing (Option A) when NAV recording is planned, because that is the point at which the
read/write asymmetry becomes acute.

---

### Clean Architecture Impact (Full ES)

| Layer | Change |
|-------|--------|
| **Domain** | `Fund`/`FundClass` become event-sourced aggregates: `Apply(FundCreatedEvent)` etc. Domain has zero new dependencies. |
| **Application** | Handlers call `aggregate.Handle(command)` → collect raised events → persist via `IEventStore`. No SaveChanges. |
| **Infrastructure** | `IEventStore` implemented with Marten (PostgreSQL) or EventStoreDB. Projections built as Marten read models or separate hosted service. |
| **Presentation** | No change — controllers/endpoints unchanged. |

The `IUnitOfWork` abstraction would be **replaced** (or augmented) with `IEventStore`:

```csharp
public interface IRegistryEventStore
{
    Task AppendAsync<TAggregate>(Guid aggregateId, IEnumerable<IDomainEvent> events, int expectedVersion, CancellationToken ct = default);
    Task<TAggregate?> LoadAsync<TAggregate>(Guid aggregateId, CancellationToken ct = default) where TAggregate : IEventSourcedAggregate;
}
```

---

### Snapshot Strategy

Replaying 10,000 events to load a fund aggregate is unacceptable. Implement snapshots:

- Snapshot every N events (e.g., every 50)
- Load: fetch latest snapshot + events after snapshot version
- Marten handles this automatically with `UseOptimisticConcurrency` + snapshot stores

---

### Interaction with Existing Integration Events

The existing `FundStatusChangedEvent`, `ClassCreatedEvent`, `ClassStatusChangedEvent` are
**integration events** (cross-module). With event sourcing, these should be published
**after** the event stream is durably persisted, not before. The pattern is:

```
1. Persist domain events to event store (durable)
2. Projection updates read model
3. Outbox: publish integration events to IIntegrationEventBus
```

Consider a **transactional outbox** table to guarantee exactly-once delivery of integration
events when moving to full ES.

---

### ABAC Considerations

The existing ABAC `SameTenant` + `IsActive` templates read resource attributes from the
**current state** of the entity (via the read model). With event sourcing:

- ABAC checks on **commands** use the projection (current read model) — no change
- ABAC checks for **temporal queries** (e.g., "what was this fund's state on date X?")
  require point-in-time projection rebuilds — this is a future capability

---

### Open Questions for Event Sourcing

1. **Event store technology** — Marten (PostgreSQL, fits existing stack) vs EventStoreDB
   (purpose-built, separate server). Marten is lower operational overhead.
2. **Projection consistency** — synchronous (inline, strong consistency) or asynchronous
   (eventual consistency)? For a regulated system, synchronous projections are safer.
3. **Scope** — Registry only, or will Holdings also move to ES? Holdings is already
   effectively event-sourced in spirit (mutations only via integration events). Formalising
   this is low effort.
4. **Migration** — existing Registry data must be converted to seed events (a one-time
   migration producing `FundCreatedEvent` + `ClassCreatedEvent` records from current DB
   state).
5. **Versioning** — how will event schema changes be handled? Upcasting strategy needed
   from day one.

---

## Summary

| Topic | Recommendation | When |
|-------|---------------|------|
| FrankieOne | New `IKycService` abstraction in CRM.Application; FrankieOne adapter in CRM.Infrastructure; enrich `KycStatus` enum on Investor; webhook endpoint with HMAC validation | When KYC flow is prioritised |
| Event Sourcing | Start with hybrid Option B (event log alongside EF); migrate Registry to full ES when NAV module is planned | Hybrid now; full ES with NAV module |
| Holdings ES | Formalise Holdings as fully event-sourced alongside Registry full ES | Same time as Registry |
| Outbox pattern | Required before full ES to guarantee integration event delivery | With full ES |
