# Plan: Order Instruction Model — Calastone STP Integration Layer

**Status:** Implementing

---

## Overview

Introduces an `Order` entity as the top-level domain concept representing an investor instruction, aligned with the Calastone Executing Party REST API (V3.0 spec). Today, IFX's `Transaction` entity conflates the instruction (what the investor wants) with the execution record (what happened). This causes structural gaps: Switch orders use a `TargetClassId` shortcut instead of proper legs; there is no accept/reject workflow; no external order references; no currency fields; no charge/commission/tax breakdown; and no fund identifier mapping (ISIN/APIR). By introducing `Order → Transaction legs` hierarchy, IFX aligns with ISO 20022–based fund industry STP patterns and becomes ready for Calastone integration as an Executing Party.

---

## Goals

- Introduce `Order` domain entity in the Transaction module (wraps one or more `Transaction` legs)
- `OrderStatus` lifecycle: `Submitted → Accepted → PriceConfirmed | Rejected | Cancelled`
- Switch Orders carry two legs: a Redemption leg + a Subscription leg (replaces `TargetClassId` shortcut)
- Add external reference fields: `OrderReference` (ordering party ref), `DealReference` (executing party ref)
- Add `Currency` (ISO 3-letter) to `Transaction` so amount is always `(Amount, Currency)`
- Add `ExternalFundIdentifier` value object to `Transaction` leg (ISIN / APIR / CUSIP / SEDOL + type)
- Add `DealingPriceDetails` to `Transaction` leg (price type code, amount, currency) replacing bare `NAVPrice`
- Add `ChargeDetails[]`, `CommissionDetails[]`, `TaxDetails[]` collections to `Transaction` leg
- Add `OrderConfirm` workflow: `POST /api/v1/order/{id}/accept`, `POST /api/v1/order/{id}/reject`, `POST /api/v1/order/{id}/confirm`
- Existing `POST /api/v1/transaction/{subscription,redemption,switch}` endpoints become Order creation shortcuts (backward compatible — they create an Order + leg(s) and return the existing `TransactionDto` shape)
- All new endpoints are multi-tenant and ABAC-protected (SameTenant template)
- `ITransactionReader` (Abstractions) extended to expose Order-level queries

---

## Non-Goals

- Full Calastone REST API client (outbound HTTP calls to Calastone) — this plan models the domain only
- Transfer type refactor — `Transfer` remains a Transaction-only type (no Calastone equivalent)
- FX details (`fXDetails` in spec) — deferred to Pricing module
- Tax details seeding / PolicyDefinition rows for new endpoints — separate seed migration task
- Frontend UI for Order management — separate plan
- Real Calastone connectivity / mutual TLS / token management — infrastructure integration plan
- Pagination for `GET /api/v1/order` (can be added as delta)
- `fundProviderIdentifier` routing field (Calastone internal concern, not stored in our domain model)

---

## Architecture

### Layers Touched

| Layer | Changes |
|---|---|
| **Domain** | New `Order` entity, `OrderStatus` / `OrderLegType` enums, `ExternalFundIdentifier` value object, `DealingPriceDetails` value object, `ChargeDetail` / `CommissionDetail` / `TaxDetail` owned types, `OrderStatus` domain events |
| **Application** | New commands: `CreateOrder`, `AcceptOrder`, `RejectOrder`, `ConfirmOrder`; new queries: `GetOrder`, `GetOrders`; updated `CreateSubscription` / `CreateRedemption` / `CreateSwitch` to create Order + legs; updated `ProcessTransaction` command maps to `ConfirmOrder` |
| **Infrastructure** | EF Core config for `Orders` + `OrderLegs` tables; update `Transactions` table to add `OrderId` FK, `Currency`, `ExternalFundIdentifier` columns; owned type config for charge/commission/tax collections |
| **Presentation** | New endpoints under `/api/v1/order`; existing `/api/v1/transaction/{type}` endpoints remain unchanged externally |
| **Abstractions** | `ITransactionReader` gains `GetOrderAsync`, `GetOrdersByAccountAsync` |

### New Domain Model

```
Order (aggregate root)
├── Id                      Guid (UUID v7)
├── TenantId                Guid
├── OrderReference          string(35)       ← ordering party external ref
├── DealReference           string?          ← executing party ref, set on Accept
├── OrderType               OrderType        ← SubscriptionOrder | RedemptionOrder | SwitchOrder
├── Status                  OrderStatus      ← Submitted | Accepted | PriceConfirmed | Rejected | Cancelled
├── RejectionReason         string?
├── ExpectedTradeDate       DateOnly?        ← set on Accept
├── ExpectedSettlementDate  DateOnly?        ← set on Accept
├── CreatedAt/UpdatedAt     audit fields
└── Legs: List<Transaction>

Transaction (leg — existing entity, extended)
├── (existing fields retained)
├── OrderId                 Guid?            ← nullable FK to Order (null = legacy direct transactions)
├── LegId                   string?          ← Switch only: ordering party leg reference
├── Currency                string(3)        ← ISO currency code (new, default "AUD")
├── ExternalFundIdentifier  ExternalFundIdentifier? ← value object: Type + Identifier + OtherType?
├── DealingPriceDetails     DealingPriceDetails?    ← owned: PriceType + Amount + Currency
├── ChargeDetails           List<ChargeDetail>      ← owned collection
├── CommissionDetails       List<CommissionDetail>  ← owned collection
└── TaxDetails              List<TaxDetail>         ← owned collection
```

### New Value Objects / Owned Types

```csharp
// Value object
record ExternalFundIdentifier(string Type, string Identifier, string? OtherType);
// Types: "ISIN" | "SEDOL" | "APIR" | "CUSIP" | "OTHER"

// Owned types
record DealingPriceDetails(string PriceType, decimal Amount, string Currency);
record ChargeDetail(string Type, decimal? Rate, decimal Amount, string Currency);
record CommissionDetail(string Type, decimal? Rate, decimal Amount, string Currency, decimal? PercentageWaived);
record TaxDetail(string Type, decimal? Rate, decimal Amount, string Currency, bool? ExemptionIndicator, string? ExemptionReason);
```

### New Endpoints

```
POST   /api/v1/order                          CreateOrder (full Order Instruction)
GET    /api/v1/order                          GetOrders (tenant-scoped)
GET    /api/v1/order/{id}                     GetOrder
POST   /api/v1/order/{id}/accept              AcceptOrder
POST   /api/v1/order/{id}/reject              RejectOrder
POST   /api/v1/order/{id}/confirm             ConfirmOrder (price confirmation)
DELETE /api/v1/order/{id}                     CancelOrder
```

Existing (backward compatible, internally now create Order + leg):
```
POST   /api/v1/transaction/subscription       → CreateOrder(SubscriptionOrder) shortcut
POST   /api/v1/transaction/redemption         → CreateOrder(RedemptionOrder) shortcut
POST   /api/v1/transaction/switch             → CreateOrder(SwitchOrder) shortcut
POST   /api/v1/transaction/{id}/process       → ConfirmOrder (maps to first leg's confirm)
POST   /api/v1/transaction/{id}/cancel        → CancelOrder
```

### ABAC / Authorization

- All Order endpoints use `SameTenant` condition template (same pattern as Transaction)
- Required permissions: `Order:create`, `Order:read`, `Order:update`, `Order:delete`
- Seeded `PolicyDefinition` rows: platform-level defaults for IFX tenant (separate migration task)
- `AcceptOrder` / `RejectOrder` / `ConfirmOrder` require `Order:update` permission

### Multi-Tenant

- `Order.TenantId` required, list queries use `ICurrentUser.TenantId` (no query param)
- `Transaction` legs inherit `TenantId` from parent Order

---

## Implementation Steps

### Phase 1 — Domain

- [x] Add `OrderStatus` enum: `Submitted = 1, Accepted = 2, PriceConfirmed = 3, Rejected = 4, Cancelled = 5`
- [x] Add `OrderType` enum: `SubscriptionOrder = 1, RedemptionOrder = 2, SwitchOrder = 3`
- [x] Add `ExternalFundIdentifier` value object (self-validating, immutable class)
- [x] Add `DealingPriceDetails` owned type
- [x] Add `ChargeDetail`, `CommissionDetail`, `TaxDetail` owned types
- [x] Add `Order` aggregate root entity with factory methods: `CreateSubscriptionOrder`, `CreateRedemptionOrder`, `CreateSwitchOrder`
- [x] Add `Order.Accept(dealReference, expectedTradeDate?, expectedSettlementDate?)` domain method
- [x] Add `Order.Reject(reason)` domain method
- [x] Add `Order.Confirm()` domain method (transitions to PriceConfirmed)
- [x] Add `Order.Cancel()` domain method
- [x] Extend `Transaction` entity: add `OrderId?`, `LegId?`, `Currency`, `ExternalFundIdentifier?`, `DealingPriceDetails?`, `ChargeDetails`, `CommissionDetails`, `TaxDetails`
- [x] Add `IOrderRepository` interface to Domain
- [x] Add integration events: `OrderSubmittedEvent`, `OrderAcceptedEvent`, `OrderConfirmedEvent`, `OrderRejectedEvent`

### Phase 2 — Application

- [x] Add `CreateOrderCommand` + validator + handler (full Order Instruction creation)
- [x] Add `AcceptOrderCommand` + handler
- [x] Add `RejectOrderCommand` + handler
- [x] Add `ConfirmOrderCommand` + handler (maps Calastone Order Confirm to domain)
- [x] Add `CancelOrderCommand` + handler
- [x] Add `GetOrderByIdQuery` + handler
- [x] Add `GetOrdersQuery` + handler (tenant-scoped list)
- [x] Add `OrderDto`, `OrderSummaryDto`, `OrderLegDto` DTOs
- [x] Update `MappingProfile` for new DTOs
- [x] Update `ITransactionReader` in Abstractions with `GetOrderByIdAsync`, `GetOrdersByInvestmentAccountAsync`
- [ ] Refactor `CreateSubscriptionCommandHandler` → creates Order + leg internally, returns `TransactionDto` (backward compat) — deferred: existing handlers remain unchanged; Order is a parallel path
- [ ] Refactor `CreateSwitchCommandHandler` → creates SwitchOrder + two legs — deferred: backward compat path kept; migration is an opt-in step

### Phase 3 — Infrastructure

- [x] Add `OrderConfiguration` (EF entity type config): `Orders` table in `transaction` schema
- [x] Add EF owned type configs for `ChargeDetail`, `CommissionDetail`, `TaxDetail` (JSON columns)
- [x] Add `ExternalFundIdentifier` owned type config (flat columns)
- [x] Add `DealingPriceDetails` owned type config (flat columns)
- [x] Update `TransactionConfiguration`: add `OrderId` FK, `LegId`, `Currency`, new owned type columns
- [x] Add `EfOrderRepository` implementation
- [x] EF migration `AddOrderInstructionModel`: add `Orders` table, add columns to `Transactions`
- [x] Update `TransactionDbContext` to include `Orders` DbSet
- [x] Update `TransactionReader` (Abstractions impl) to support Order queries

### Phase 4 — Presentation

- [x] Add `OrderEndpoints.cs` — map all `/api/v1/order` routes
- [x] Add request models: `CreateOrderRequest`, `AcceptOrderRequest`, `RejectOrderRequest`, `ConfirmOrderRequest`
- [x] Keep existing `TransactionEndpoints.cs` unchanged (backward compat)
- [x] Register new endpoints in `EndpointExtensions` with `"Orders"` Swagger tag

### Phase 5 — Tests

- [x] Unit tests: `Order` factory methods and domain state transitions (18 new Domain tests)
- [x] Unit tests: `CreateOrderCommandHandler` — valid subscription/redemption/switch, KYC failure, class not open
- [x] Unit tests: `AcceptOrderCommandHandler` — valid + invalid status transitions, wrong tenant, not found
- [x] Unit tests: `RejectOrderCommandHandler` — valid, not found, already confirmed
- [x] Unit tests: `ConfirmOrderCommandHandler` — valid, not found, not accepted, leg not found
- [ ] Integration tests: full Order lifecycle via API (Submit → Accept → Confirm) — deferred
- [ ] Integration tests: Switch Order creates two legs with correct types — deferred

---

## Testing Plan

**Unit tests:**
- All `Order` domain method state transitions (happy + invalid transition → exception)
- `CreateSwitchOrder` creates exactly two legs with correct `TransactionType` on each
- Command handlers: valid + not-found + wrong-tenant + wrong-status scenarios

**Integration tests:**
- `POST /api/v1/order` (subscription) → 201 with Order + leg
- `POST /api/v1/order/{id}/accept` → 200, status = Accepted
- `POST /api/v1/order/{id}/confirm` → 200, status = PriceConfirmed, units/price populated
- `POST /api/v1/order/{id}/reject` → 200, status = Rejected
- Switch order: `POST /api/v1/order` (switch) → two Transaction legs created
- Existing `POST /api/v1/transaction/subscription` still returns `TransactionDto` (backward compat)

**Manual / Swagger:**
- Full Order lifecycle in Swagger UI
- Verify `X-Tenant-Id` header required and enforced
- Verify wrong-tenant 403 response

---

## Open Questions

1. **OrderId nullable on Transaction** — Legacy transactions (created before this plan) will have `OrderId = null`. Is that acceptable, or should we backfill legacy transactions into stub Orders? Recommended: leave nullable, legacy data is pre-STP.
2. **Switch legs: same FundClass or different?** — Calastone allows the subscription leg to be a different fund/class from the redemption leg. Current Switch uses `TargetClassId`. The new model supports cross-fund switches naturally. Confirm this is in scope.
3. **Currency default** — Should `Transaction.Currency` default to `"AUD"` for existing/legacy records? Recommended: yes, via EF migration default value.
4. **Charge/commission storage** — JSON column vs normalized child tables for `ChargeDetails[]`. Recommended: JSON column (simpler, no joins needed, charges are read-only after confirmation).
5. **`OrderReference` uniqueness scope** — Should `(TenantId, OrderReference)` be unique? Recommended: yes, add unique index.
6. **ABAC PolicyDefinition seeds** — Include in this plan or separate migration task? Recommended: separate, this plan focuses on the domain model.

---

## Status History

| Date | Status | Notes |
|------|--------|-------|
| 2026-04-18 | Plan | Plan created — based on Calastone Executing Party REST API V3.0 spec analysis |
| 2026-04-18 | Implementing | Phases 1–5 implemented: 56 files, +88 tests (Domain 20→38, Application 32→50), full solution clean build |
