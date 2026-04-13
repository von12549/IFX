# CRM & Fund Registry — Design Summary

**Last updated:** 2026-04-13
**Status:** CRM V1 built · Registry/Holdings/Transaction built · CRM V2 planned
**Branch:** `feature/crm-v2-investment-account-party-relationship-kyc`

---

## 1. Scope

Four modules make up the Fund Registry system. This document summarises their entity models, responsibilities, dependencies, and key design decisions.

| Module | Responsibility | DB Schema |
|---|---|---|
| **CRM** | Legal identity, KYC/AML, investment accounts, advisor model | `crm` |
| **Registry** | Fund and share class catalogue | `registry` |
| **Holdings** | Unit ledger (source of truth for balances) | `holdings` |
| **Transaction** | Subscription / redemption / transfer / switch lifecycle | `transaction` |

All entities are tenant-scoped via `TenantId`. Authorization uses the IFX Template-Based ABAC engine (`SameTenant`, `IsActive`, and new `HasAdvisoryAuthorization` templates).

---

## 2. Module Dependency Graph

```
CRM ──────────────────────────────────────────┐
  └─ ICrmReader (Abstractions)                 │
        ↑ consumed by                          │
Registry                                       │
Holdings ←── integration events from Transaction
Transaction ←── depends on ICrmReader + IRegistryReader + IHoldingsReader
```

Rules:
- **CRM has no upstream dependencies** — it is the root identity source.
- **Registry** is independent of CRM and Holdings.
- **Holdings** is read-only from the API — balances are written only by Transaction event handlers.
- **Transaction** validates all foreign keys against Abstractions interfaces; it never imports domain entities from other modules.

---

## 3. CRM Module

### 3.1 Current State (V1 — built)

```
crm.Parties                    crm.Investors
├── Id                         ├── Id
├── TenantId                   ├── TenantId
├── PartyCode                  ├── InvestorCode
├── Name                       ├── Name
├── PartyType                  ├── InvestorType
│   (FundManager / Distributor │   (Individual / Corporate / Institutional)
│    Custodian / TransferAgent ├── KycStatus  (Pending / Approved / Rejected / Expired)
│    Other)                    ├── KycReviewedAt
├── Status                     ├── ResidencyCountry
└── Audit fields               ├── TaxResidency
                               ├── Status
                               └── Audit fields

crm.PartyInvestorRelationships   ← to be retired in V2
├── PartyId → Parties
├── InvestorId → Investors
├── TenantId
├── RelationshipType
├── EffectiveDate
└── ExpiryDate
```

**Limitation:** `Party` covers only service providers (B2B). Individual investors live in `Investor` only — no `Party` record. This means `PartyId` cannot represent an individual investor in account links, and there is no formal KYC bridge between `Party` and `Investor`.

---

### 3.2 Target State (V2 — planned)

#### Party — identity redesign

`PartyType` is retired and replaced by:

| Field / Table | Meaning | Cardinality |
|---|---|---|
| `PartyLegalStructure` (column) | What the party **is** (legal form) | Required, exactly one |
| `PartyRoleAssignment` (table) | What the party **does** (business role) | Zero to many |

```
PartyLegalStructure:  Individual=1, Company=2, Trust=3, SuperFund=4

PartyFunctionalRole (enum — stored in PartyRoleAssignment.Role):
  FundManager=1, Distributor=2, Custodian=3, TransferAgent=4,
  AdvisoryFirm=5, AdvisoryBranch=6, AdvisorRep=7, Trustee=8

crm.PartyRoleAssignments
├── Id, TenantId
├── PartyId (FK → Parties)
├── Role (PartyFunctionalRole enum)
├── AssignedAt, AssignedBy
UNIQUE INDEX (TenantId, PartyId, Role)
```

**Why a junction table instead of a nullable column:** A single enum can only store one role. A Party that is simultaneously an `AdvisoryFirm` and a `Distributor`, or an `AdvisorRep` and a `Trustee`, cannot be represented with a column. The junction table handles all multi-role cases cleanly. This implements the ChatGPT design's principle: **decouple identity (Party) from behaviour (Role)**.

**"Investor" is NOT a functional role:** Being an investor is represented by the existence of an `Investor` record with `Investor.PartyId` FK. The `Investor` entity is too rich (KYC/AML, legal structure profiles, FrankieOne) to be a role row.

Examples:
- Individual investor: `LegalStructure=Individual` + no role assignments + `Investor(PartyId=...)`
- Fund Manager firm:   `LegalStructure=Company`    + role `FundManager`
- Advisory branch:     `LegalStructure=Company`    + role `AdvisoryBranch`
- Advisor + Investor:  `LegalStructure=Individual` + role `AdvisorRep` + `Investor(PartyId=...)`
- Advisor + Trustee:   `LegalStructure=Individual` + roles `AdvisorRep`, `Trustee`

**Party is now the universal legal identity for everyone** — individuals, companies, trusts, and service providers all get a Party record first.

#### Investor — KYC profile + legal-structure extension tables

`Investor` becomes the **KYC/AML role profile** for a Party. It carries fields common to all legal structures, plus a `LegalStructure` discriminator that points to a type-specific extension table.

```
crm.Investors (base — all structures)
├── Id, TenantId
├── PartyId (FK → Parties, nullable → UNIQUE per tenant)    ← V2 addition
├── InvestorCode, Name
├── LegalStructure  (replaces InvestorType)
├── KycStatus, KycReviewedAt
├── TaxResidencyCountry, TIN, FatcaCrsStatus, GIIN
├── AmlStatus, AmlGatewayReference, AmlCheckedAt
├── IsPEP, PepDetails, SourceOfWealth
├── UnresolvedPepCount, UnresolvedSanctionCount, UnresolvedAdverseMediaCount
└── Status, Audit fields

crm.IndividualInvestorProfiles          ← 1:0-1 on InvestorId
├── DateOfBirth, DateOfDeath, Gender, PlaceOfBirth
├── Nationality, IdDocumentType/Number/Country/Expiry
└── FrankieOneEntityId

crm.CorporateInvestorProfiles           ← 1:0-1 on InvestorId
├── Acn, Abn, RegistrationNumber
├── CountryOfIncorporation, IncorporationDate
├── IsPubliclyListed, Regulator, LicenceNumber
└── FrankieOneEntityId

crm.TrustInvestorProfiles               ← 1:0-1 on InvestorId
├── TrustType, TrustDeedReference, TrustEstablishedDate
├── TrusteePartyId (FK → Parties)
└── FrankieOneEntityId
```

**Design rationale:** EF inheritance strategies (TPH/TPT/TPC) are avoided. TPH creates nullable sprawl; EF TPT generates poor SQL; TPC breaks FK references to the abstract base. Explicit composition gives DB-level NOT NULL constraints per type, no joins on list queries, and zero changes to `Investor` or existing profiles when a new legal structure is added.

#### InvestmentAccount — sits between Party and Holdings

```
crm.InvestmentAccounts
├── Id, TenantId
├── AccountNumber (UNIQUE per tenant)
├── InvestmentAccountType
│   (Individual / Joint / Trust / Corporate / SuperannuationFund / Partnership / Other)
├── Status  (Active / Inactive / Locked)
├── CertificateDate
└── Audit fields
```

An `InvestmentAccount` is a **client vessel** — created during onboarding before any holdings exist. It belongs in CRM (not Holdings) because its lifecycle is managed by client services, `PartyInvestmentAccountLink` and `AdvisorInvestmentAccountLink` are CRM-domain relationships, and Holdings → CRM (not the reverse).

#### PartyInvestmentAccountLink — replaces PartyInvestorRelationship

```
crm.PartyInvestmentAccountLinks
├── Id, TenantId
├── PartyId (FK → Parties)
├── InvestmentAccountId (FK → InvestmentAccounts)
├── RelationshipType  (InvestmentAccountRelationshipType)
│   RegisteredHolder / BeneficialHolder / TrustBeneficiary / ControllingEntity / Agent
├── OwnershipPercentage (decimal?)
├── LinkOrder (int — for joint accounts)
├── EffectiveDate, ExpiryDate
└── Audit fields
```

Business rules enforced in `LinkPartyToInvestmentAccountCommandValidator`:
- Non-joint accounts may have only one `RegisteredHolder`
- `LinkOrder` must be unique within an account
- Total `OwnershipPercentage` across `RegisteredHolder` links cannot exceed 100%

#### PartyRelationship — Party-to-Party graph

```
crm.PartyRelationships
├── Id, TenantId
├── FromPartyId (FK → Parties)
├── ToPartyId (FK → Parties)
├── RelationshipType  (PartyRelationshipType)
│   ParentFirm / AuthorizedToAdvise / BeneficialOwner / ControllingEntity / TrustBeneficiary
├── EffectiveDate, ExpiryDate
└── Audit fields
```

Unique index: `(FromPartyId, ToPartyId, RelationshipType)` filtered by `ExpiryDate IS NULL`.

#### AdvisorInvestmentAccountLink — ongoing account access

```
crm.AdvisorInvestmentAccountLinks
├── Id, TenantId
├── AdvisorPartyId (FK → Parties — must be AdvisoryFirm or AdvisoryBranch)
├── InvestmentAccountId (FK → InvestmentAccounts)
├── RebateRate (decimal?)
├── EffectiveDate, ExpiryDate
└── Audit fields
```

#### InvestorDocument — identity document store

```
crm.InvestorDocuments
├── Id, TenantId
├── InvestorId (FK → Investors)
├── DocumentType  (Passport / DriverLicence / NationalId / BirthCertificate / Other)
├── DocumentNumber, IssueCountry (ISO alpha-2), IssueState
├── IssueDate, ExpiryDate
└── Audit fields
```

#### Two-Layer Advisor Authorization (ABAC)

Advisors need two distinct authorizations:

| Layer | Authorizes | Stored in | Evaluated by |
|---|---|---|---|
| 1 | Can create investments **for** investor X | `PartyRelationship(AuthorizedToAdvise)` | `HasAdvisoryAuthorization` C# template |
| 2 | Can **manage** investment account Y | `AdvisorInvestmentAccountLink` | `IsAdvisorForAccount` C# template |

Both templates traverse the `PartyRelationship(ParentFirm)` hierarchy (max depth 3) so that a branch-level or individual-rep authorization cascades from the parent firm. A per-request in-memory cache prevents N+1 queries.

---

#### UserPartyLink — User ↔ Party bridge

Bridges the Auth module's `User` identity to a CRM `Party` record. Stored in CRM; references `UserId` by Guid value only — no cross-schema FK, preserving module isolation.

```
crm.UserPartyLinks
├── Id, TenantId
├── UserId (Guid — value reference to auth.Users, no FK)
├── PartyId (FK → crm.Parties)
└── Audit fields

Indexes: UNIQUE(TenantId, UserId)   — one Party per User per tenant
         (no unique on PartyId)     — multiple users may link to the same corporate Party
```

When an admin calls `LinkUserToPartyCommand`, the `party_id` claim is written to the User via `IIdentityProvider.UpdateUserClaimsAsync`. On next login the JWT carries `party_id`, which `ICurrentUser.PartyId` reads — zero DB lookups per request.

**This pattern covers both portals:**

| Portal | User's Party | Party type | Profile |
|---|---|---|---|
| AdvisorPortal | `Party(Individual, AdvisorRep)` | Advisor rep | Linked to firm/branch via `PartyRelationship(ParentFirm)` |
| InvestorPortal | `Party(Individual, null)` | Individual investor | `Investor(PartyId=...)` for KYC, accounts, holdings |

---

## 4. Registry Module (built)

```
registry.Funds
├── Id, TenantId
├── FundCode, FundName
├── FundType  (UCITS / AIF / Hedge / ETF / PrivateEquity / Other)
├── BaseCurrency (ISO 4217)
├── InceptionDate
├── Status  (Active / Closed / Liquidating)
└── Audit fields

registry.FundClasses
├── Id, TenantId
├── FundId (FK → Funds)
├── ClassCode, ClassName
├── Currency (ISO 4217)
├── MinInitialInvestment (decimal?)
├── ManagementFeeRate (decimal?)
├── PerformanceFeeRate (decimal?)
├── NavFrequency  (Daily / Weekly / Monthly / Quarterly)
├── Status  (Active / SoftClosed / Closed / Liquidating)
└── Audit fields
```

A `FundClass` is the unit of investment — Holdings and Transactions reference `ClassId`, not `FundId` directly.

---

## 5. Holdings Module (V2 — account-centric)

```
holdings.Holdings
├── Id, TenantId
├── InvestmentAccountId  (Guid — value ref to crm.InvestmentAccounts)  ← V2: was InvestorId
├── ClassId              (Guid — value ref to registry.FundClasses)
├── Units (decimal — the unit balance)
├── Status  (Active / Frozen / Closed)
├── LastTransactionAt
└── Audit fields

UNIQUE INDEX (TenantId, InvestmentAccountId, ClassId)
```

The unique constraint prevents a double-processed transaction event from silently creating two rows for the same position. `Holding` is a current-state view with no lot tracking — one row per (Account, Class) is the invariant.

Holdings belong to an **investment account**, not directly to an investor. This is necessary because:
- A joint account has two registered holders — `InvestorId` would require picking one arbitrarily
- An investor with two accounts has independent unit balances per account
- Advisors link to `InvestmentAccount`, not `Investor` — account-level FK makes advisor-holdings queries natural

**Holdings are written only by Transaction event handlers** — never directly via API. The API is read-only:
- `GET /api/v1/holding` — list
- `GET /api/v1/holding/{id}`
- `GET /api/v1/investor/{investorId}/holdings`
- `GET /api/v1/fund/{fundId}/class/{classId}/holdings`

When a Transaction is processed, it emits a `TransactionProcessedEvent` → Holdings event handler applies `ApplySubscription(units)` / `ApplyRedemption(units)` / `ApplyTransfer(units)` to the relevant `Holding` record.

---

## 6. Transaction Module (V2 — account-centric)

```
transaction.Transactions
├── Id, TenantId
├── Type  (Subscription / Redemption / Transfer / Switch)
├── InvestmentAccountId  (Guid — value ref)  ← V2: replaces InvestorId + PartyId
├── FundId, ClassId
├── TargetClassId (for Transfer and Switch)
├── Amount (decimal — money amount at creation)
├── Units (decimal? — calculated at Process time: Units = Amount / NAVPrice)
├── NAVPrice (decimal? — set when processed)
├── TradeDate, SettlementDate
├── Status  (Pending / Processing / Processed / Settled / Cancelled / Failed)
├── FailureReason (string?)
└── Audit fields
```

#### Transaction Lifecycle

```
Pending ──[Process(navPrice)]──► Processed ──[Settle]──► Settled
   │                                │
   └──[Cancel]──► Cancelled         └──[Fail]──► Failed
```

`Process(navPrice)` calculates `Units = Amount / navPrice` (8 decimal places) and emits `TransactionProcessedEvent`, which Holdings handles to update the unit balance.

#### Transaction Type Semantics

| Type | Source Class | Target Class | Holdings Effect |
|---|---|---|---|
| Subscription | ClassId | — | +Units on ClassId |
| Redemption | ClassId | — | −Units on ClassId |
| Transfer | ClassId | TargetClassId | −Units on ClassId, +Units on TargetClassId |
| Switch | ClassId | TargetClassId | −Units on ClassId, +Units on TargetClassId |

---

## 7. ICrmReader — Cross-Module Contract

Other modules consume CRM data only through `ICrmReader` (in `CRM.Abstractions`):

```csharp
// V1 (current)
Task<PartySummaryDto?>    GetPartyByIdAsync(Guid partyId, Guid tenantId, CancellationToken ct);
Task<InvestorSummaryDto?> GetInvestorByIdAsync(Guid investorId, Guid tenantId, CancellationToken ct);
Task<bool>                IsInvestorKycApprovedAsync(Guid investorId, Guid tenantId, CancellationToken ct);
Task<bool>                PartyExistsAsync(Guid partyId, Guid tenantId, CancellationToken ct);

// V2 additions (planned)
Task<InvestmentAccountSummaryDto?> GetInvestmentAccountByIdAsync(Guid accountId, Guid tenantId, CancellationToken ct);
Task<bool>                         InvestmentAccountExistsAsync(Guid accountId, Guid tenantId, CancellationToken ct);
Task<bool>                         AdvisorIsAuthorizedForInvestorAsync(Guid advisorPartyId, Guid investorPartyId, Guid tenantId, CancellationToken ct);
Task<bool>                         IsPartyKycApprovedAsync(Guid partyId, Guid tenantId, CancellationToken ct);
```

`IsPartyKycApprovedAsync` (V2) resolves `PartyId → Investor.KycStatus = Approved` — enabling the Transaction module's KYC gate to work with `PartyId` alone once V2 is implemented.

---

## 8. Key Design Decisions

| Decision | Choice | Rationale |
|---|---|---|
| `PartyType` split | `PartyLegalStructure` (required column) + `PartyRoleAssignment` (junction table, multi-role) | Legal structure and business role are orthogonal; a Party can hold multiple simultaneous roles (e.g. AdvisorRep + Trustee); single nullable enum cannot represent this |
| `Investor` ↔ `Party` link | `Investor.PartyId` FK (nullable, UNIQUE per tenant) | Eliminates dual-identity problem; low-cost; one-to-zero-or-one enforced by filtered UNIQUE index |
| Investor extension tables | Explicit composition (not EF inheritance) | Avoids TPH nullable sprawl, EF TPT poor SQL, TPC FK issues; extensible without altering base table |
| `InvestmentAccount` location | CRM module | Created before holdings exist; lifecycle managed by client services; Holdings → CRM dependency direction must not reverse |
| Advisor ABAC | C# `AdvisoryAuthorizationTemplate` | OPA cannot query the DB; C# template keeps traversal logic testable and consistent with existing templates |
| `PartyInvestorRelationship` | Retired (clean drop) | Zero rows on branch; superseded by `PartyInvestmentAccountLink` which links to `InvestmentAccount` not `Investor` directly |
| Joint account validation | Application-layer only | Consistent with IFX pattern; no external tooling bypasses the application layer |
| Holdings/Transaction FK | `InvestmentAccountId` replaces `InvestorId` (+ `PartyId` removed from Transaction) | Holdings and trades belong to an account; joint/trust/multi-account scenarios break the 1:1 assumption of `InvestorId` |
| Holdings writes | Event-driven only | Enforces single source of truth; Holdings is an eventual-consistency ledger, not a transactional service |
| Advisor/Investor User bridge | `UserPartyLink` + `party_id` JWT claim + `ICurrentUser.PartyId`; many-to-one (multiple users may link to same corporate Party) | Individual advisor reps and investors need a User↔Party link; corporate parties allow multiple authorized staff logins; only `UNIQUE(TenantId, UserId)` enforced |
| Holdings uniqueness | `UNIQUE(TenantId, InvestmentAccountId, ClassId)` on `holdings.Holdings` | Prevents duplicate position rows from double-processed events; `Holding` is a current-state view, one row per (Account, Class) is invariant |
| PartyRelationship direction | XML doc convention per enum value + direction guard in `CreatePartyRelationshipCommandValidator` | `FromPartyId → ToPartyId` semantics are per-type (e.g. `ParentFirm`: rep → firm); validator prevents inverted relationships that would silently corrupt ABAC hierarchy traversal |

---

## 9. API Endpoints Reference

### CRM
```
GET    /api/v1/party
POST   /api/v1/party
GET    /api/v1/party/{id}
PUT    /api/v1/party/{id}
DELETE /api/v1/party/{id}
GET    /api/v1/party/{id}/investors                    ← V1 (to be reworked in V2)
POST   /api/v1/party/{id}/investors/{investorId}       ← V1 retire in V2
DELETE /api/v1/party/{id}/investors/{investorId}       ← V1 retire in V2
GET    /api/v1/party/{id}/relationships                ← V2
POST   /api/v1/party/{id}/relationships                ← V2
DELETE /api/v1/party/{id}/relationships/{relId}        ← V2

GET    /api/v1/investor
POST   /api/v1/investor
GET    /api/v1/investor/{id}
PUT    /api/v1/investor/{id}
DELETE /api/v1/investor/{id}
PUT    /api/v1/investor/{id}/kyc
GET    /api/v1/investor/{id}/documents                 ← V2
POST   /api/v1/investor/{id}/documents                 ← V2
DELETE /api/v1/investor/{id}/documents/{docId}         ← V2

GET    /api/v1/investment-account                      ← V2
POST   /api/v1/investment-account                      ← V2
GET    /api/v1/investment-account/{id}                 ← V2
PUT    /api/v1/investment-account/{id}                 ← V2
DELETE /api/v1/investment-account/{id}                 ← V2
GET    /api/v1/investment-account/{id}/parties         ← V2
POST   /api/v1/investment-account/{id}/parties         ← V2
DELETE /api/v1/investment-account/{id}/parties/{partyId}  ← V2
GET    /api/v1/investment-account/{id}/advisors        ← V2
POST   /api/v1/investment-account/{id}/advisors        ← V2
DELETE /api/v1/investment-account/{id}/advisors/{advisorPartyId}  ← V2
```

### Registry
```
GET    /api/v1/fund
POST   /api/v1/fund
GET    /api/v1/fund/{id}
PUT    /api/v1/fund/{id}
DELETE /api/v1/fund/{id}
GET    /api/v1/fund/{fundId}/class
POST   /api/v1/fund/{fundId}/class
GET    /api/v1/fund/{fundId}/class/{id}
PUT    /api/v1/fund/{fundId}/class/{id}
DELETE /api/v1/fund/{fundId}/class/{id}
```

### Holdings (read-only)
```
GET    /api/v1/holding
GET    /api/v1/holding/{id}
GET    /api/v1/investor/{investorId}/holdings
GET    /api/v1/fund/{fundId}/class/{classId}/holdings
```

### Transaction
```
GET    /api/v1/transaction
POST   /api/v1/transaction
GET    /api/v1/transaction/{id}
POST   /api/v1/transaction/subscription
POST   /api/v1/transaction/redemption
POST   /api/v1/transaction/transfer
POST   /api/v1/transaction/switch
POST   /api/v1/transaction/{id}/process
POST   /api/v1/transaction/{id}/cancel
```

---

## 10. Build Status

| Module | Domain | Application | Infrastructure | Presentation | Tests |
|---|---|---|---|---|---|
| CRM V1 | ✅ | ✅ | ✅ | ✅ | ✅ |
| CRM V2 | Planned | Planned | Planned | Planned | Planned |
| Registry | ✅ | ✅ | ✅ | ✅ | ✅ |
| Holdings | ✅ | ✅ | ✅ | ✅ | ✅ |
| Transaction | ✅ | ✅ | ✅ | ✅ | ✅ |

**CRM V2 plan:** `.claude/Plans/20260413-crm-v2-investment-account-party-relationship-kyc.md`
**Original V1 plan:** `.claude/Plans/20260401-fund-registry-crm-registry-holdings-transaction.md`
**Taurus schema analysis:** `docs/crm/taurus_inv_schema_analysis.md`
**Advisor design discussion:** `docs/crm/crm_advisor_design_discussion.md`
