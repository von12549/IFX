# Future Modules: Pricing, Distribution, Commission, Billing

**Date:** 2026-04-16
**Status:** Design Discussion — Not Yet Implemented
**Depends on:** Registry, Holdings, Transaction, CRM modules (all live on main)

---

## Overview

Four new domain modules identified as natural extensions of the Fund Registry system. Each represents a complete financial sub-domain with its own entities, lifecycle, approval workflow, and regulatory obligations. Batch jobs are the *trigger mechanism* for these modules, not their entirety.

---

## Module 1: Pricing (UnitPrice / NAV)

### Why a separate module?
NAV is an independent business process, not a property of FundClass. It has its own lifecycle, time-series history, approval workflow, and amendment tracking — analogous to how Holdings is separate from Registry.

### Entity

```csharp
UnitPrice
├── Id (UUID v7)
├── TenantId
├── ClassId (Guid)           // logical FK → FundClass, no DB constraint
├── PriceDate (DateOnly)
├── NavPerUnit (decimal)
├── Status (UnitPriceStatus)
├── PublishedAt (DateTime?)
├── AmendedFromId (Guid?)    // links to original price if this is a correction
└── IAuditableEntity

enum UnitPriceStatus { Provisional, Approved, Published, Amended }
```

### Relationship to FundClass
- `FundClass.NavFrequency` (Daily/Weekly/Monthly/Quarterly) defines the *expected pricing schedule*
- `UnitPrice` records are the *actual published prices*
- One FundClass → many UnitPrice records (time-series)

### Impact on Transaction module
Currently `Transaction.Process(navPrice)` accepts a caller-supplied price. With Pricing module:
- Transaction queries `IPricingReader.GetApprovedNavAsync(classId, priceDate)` instead
- Price is sourced from an approved NAV record, not passed externally

### Batch Jobs
| Job | Frequency |
|-----|-----------|
| `PublishScheduledNav` | Per `FundClass.NavFrequency` |
| `ExpireStaleProvisionalPrices` | Daily |

### Module structure
```
Modules/Pricing/
 ├── Abstractions/    → IPricingReader, UnitPriceSummaryDto
 ├── Domain/          → UnitPrice, UnitPriceStatus
 ├── Application/     → PublishNav, AmendNav, GetNavHistory, GetLatestNav
 ├── Infrastructure/  → PricingDbContext (schema: pricing)
 ├── Presentation/    → GET/POST /api/v1/pricing/class/{classId}
 └── Composition/     → PricingModuleInstaller, recurring jobs
```

---

## Module 2: Distribution

### What it is
A fund distributes income (interest, dividends, capital gains) to investors. Can be paid as cash or reinvested as new units. When reinvested, Holdings must be updated.

### Lifecycle
```
Declared → Record Date (snapshot holdings) → Calculate Entitlements
    → Approved → Payment Date → Cash Payment OR Reinvestment → Settled
```

### Key entities
```csharp
DistributionDeclaration
├── ClassId, RatePerUnit, RecordDate, PaymentDate
├── DistributionType (Income | Capital | Mixed)
└── Status (Declared | Approved | Processing | Settled)

DistributionEntitlement          // per InvestmentAccount at Record Date
├── InvestmentAccountId, Units, EntitlementAmount
└── ReinvestmentUnits (if reinvested)

DistributionPayment              // settlement confirmation
├── EntitlementId, PaidAt, PaymentMethod (Cash | Reinvestment)
└── Status
```

### Cross-module dependencies
```
Distribution reads  → Holdings.Abstractions   (units held at Record Date)
Distribution reads  → Registry.Abstractions   (FundClass distribution rate)
Distribution emits  → integration event       (reinvestment → Holdings update)
```

### Batch Jobs
| Job | Frequency |
|-----|-----------|
| `SnapshotHoldingsAtRecordDate` | On Record Date |
| `CalculateEntitlements` | After Record Date snapshot |
| `ProcessReinvestments` | On Payment Date |
| `ProcessCashPayments` | On Payment Date |

---

## Module 3: Commission

### What it is
Calculates and settles advisor/distributor commissions based on `AdvisorInvestmentAccountLink.RebateRate`. Two commission types exist:

| Type | Basis | Trigger |
|------|-------|---------|
| **Trailing** | % of FUM (Holdings market value) | Monthly/quarterly recurring |
| **Upfront** | % of Transaction amount | On subscription/redemption |

### Key entities
```csharp
CommissionStatement              // one per advisor per period
├── AdvisorPartyId, PeriodStart, PeriodEnd
├── TotalAmount, Status (Calculated | Approved | Paid)
└── LineItems → CommissionLineItem[]

CommissionLineItem
├── InvestmentAccountId
├── CommissionType (Trailing | Upfront)
├── BasisAmount (FUM or Transaction amount)
├── RebateRate, CommissionAmount
└── SourceTransactionId (nullable, for Upfront only)
```

### Cross-module dependencies
```
Commission reads → Holdings.Abstractions      (period-end FUM for Trailing)
Commission reads → Transaction.Abstractions   (subscription amounts for Upfront)
Commission reads → CRM.Abstractions           (AdvisorLink.RebateRate)
```

### Batch Jobs
| Job | Frequency |
|-----|-----------|
| `CalculateTrailingCommissions` | Monthly / Quarterly |
| `CalculateUpfrontCommissions` | On Transaction settlement |
| `GeneratePaymentInstructions` | After commission approval |

---

## Module 4: Billing (Direct Fees & Charges)

### What it is
Management and performance fees are already captured in NAV (handled by Pricing module). Billing covers fees charged *directly to investors* — outside of NAV — that affect Holdings unit balances.

| Fee Type | Handled by |
|----------|-----------|
| Management Fee (annual %) | Pricing (NAV accrual) |
| Performance Fee | Pricing (NAV accrual) |
| Transaction Fee | Transaction module (deducted at trade) |
| **Account Fee** (periodic flat/%) | **Billing** |
| **Direct Charge** (ad-hoc) | **Billing** |

### Key entities
```csharp
FeeAccrual
├── ClassId, FeeType, AccruedAmount, AccrualDate
└── Status (Accrued | Applied | Reversed)

InvestorCharge
├── InvestmentAccountId, ChargeType, Amount, ChargeDate
├── Status (Pending | Applied | Waived)
└── UnitReduction (nullable — if settled by redeeming units)
```

### Cross-module dependencies
```
Billing reads  → Holdings.Abstractions    (account balance for fee calculation)
Billing reads  → Registry.Abstractions    (FundClass fee rates)
Billing emits  → integration event        (unit reduction → Holdings update)
```

### Batch Jobs
| Job | Frequency |
|-----|-----------|
| `AccrueManagementFees` | Daily (feeds into Pricing NAV) |
| `ApplyAccountFees` | Monthly |
| `ApplyDirectCharges` | Ad-hoc / scheduled |

---

## Module 5: Operations (Cross-Module Orchestration)

All multi-module batch jobs are registered here. Only depends on `.Abstractions` projects — never on any module's Domain, Application, or Infrastructure.

### Recurring Jobs
| Job | Modules Involved | Schedule |
|-----|-----------------|----------|
| `EndOfDayProcessing` | Pricing → Transaction → Holdings | Daily EOD |
| `EndOfMonthProcessing` | Commission + Distribution + Billing | Monthly |
| `InvestorStatementGeneration` | CRM + Holdings + Transaction | Monthly |
| `RegulatoryReporting` | Registry + Holdings + Transaction | Monthly/Quarterly |
| `KycExpiryCheck` | CRM | Daily |
| `FundAutoClose` | Registry | Daily |
| `HoldingsReconciliation` | Holdings + Transaction | Daily |

### Module structure
```
Modules/Operations/
 ├── Application/     → EOD/EOM job handlers (MediatR commands)
 ├── Presentation/    → POST /api/v1/operations/trigger/{jobName} (manual trigger)
 └── Composition/     → registers all Hangfire recurring jobs
```

---

## Full Module Roadmap

```
Current (live on main):
 ✅ CRM           (Party, Investor, InvestmentAccount)
 ✅ Registry      (Product, Fund, FundClass)
 ✅ Holdings      (unit ledger, event-driven)
 ✅ Transaction   (sub/redeem/transfer/switch)

Proposed (future):
 ⏳ Pricing       (UnitPrice / NAV)               ← highest priority
 ⏳ Distribution  (income distribution)
 ⏳ Commission    (advisor/distributor commissions)
 ⏳ Billing       (direct investor fees/charges)
 ⏳ Operations    (cross-module batch orchestration)
```

## Implementation Order (Recommended)

1. **Pricing** — unblocks Transaction from hard-coded navPrice parameter
2. **Operations** — registers single-module jobs from existing modules (Settlement, KYC expiry, etc.)
3. **Distribution** — depends on Pricing (needs published NAV for reinvestment unit calculation)
4. **Commission** — depends on Transaction settlement being stable
5. **Billing** — depends on Pricing (NAV accrual feeds) and Holdings (unit reduction)
