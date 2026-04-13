# Plan: CRM V2 — InvestmentAccount, PartyRelationship, Advisor Model, KYC Enrichment

**Status:** Plan

---

## Overview

The initial CRM module (delivered in `20260401-fund-registry-crm-registry-holdings-transaction`) established a working foundation with `Party`, `Investor`, and `PartyInvestorRelationship`. Analysis of the legacy Taurus `inv` schema and ChatGPT design discussion (see `/docs/crm/`) revealed significant structural gaps that must be addressed before the Holdings module is extended and before production data exists. This plan delivers CRM V2: introducing `InvestmentAccount` as a first-class entity, replacing the flat `PartyInvestorRelationship` with a proper `PartyInvestmentAccountLink`, adding a general-purpose `PartyRelationship` table for Party-to-Party structures (advisor hierarchy + corporate investor ownership chains), wiring a two-layer advisor authorization model via ABAC, enriching `Investor` with FATCA/CRS, PEP, AML, and FrankieOne-compatible KYC fields, and — since `InvestmentAccount` is the correct unit of investment activity — migrating `Holding` and `Transaction` from `InvestorId` FK to `InvestmentAccountId` FK.

---

## Goals

- Introduce `InvestmentAccount` entity in the CRM module (sits between `Party` and `Holdings` unit records)
- Introduce `PartyInvestmentAccountLink` (Party → InvestmentAccount with RelationshipType + OwnershipPercentage) — replaces `PartyInvestorRelationship`
- Introduce `PartyRelationship` (Party → Party with RelationshipType) for advisor hierarchy and corporate investor structures
- Introduce `AdvisorInvestmentAccountLink` (Advisor Party → InvestmentAccount with RebateRate + effective dates)
- Retire `PartyType` on `Party`; replace with `PartyLegalStructure` (required, single) + `PartyRoleAssignment` table (multi-role, replaces single nullable `PartyFunctionalRole` column)
- Enrich `Investor` with KYC/AML fields drawn from Taurus and FrankieOne model
- Add `InvestorDocument` child entity for identity documents
- Add OPA ABAC condition template `HasAdvisoryAuthorization` for advisor access policy
- Add `AdvisorRep = 7` to `PartyFunctionalRole` enum; store via `PartyRoleAssignment` — a Party can now hold multiple simultaneous functional roles (e.g. Investor + AdvisorRep + Trustee)
- Introduce `UserPartyLink` entity — bridges `User` (auth) to `Party` (CRM) by storing `UserId` as a value reference; enables `ICurrentUser.PartyId` for ABAC evaluation
- Add `party_id` custom claim to JWT — set at provisioning/link time; read by `ICurrentUser.PartyId`
- Update `ICrmReader` to expose `InvestmentAccount` and `PartyRelationship` queries
- **Migrate `Holding` from `InvestorId` → `InvestmentAccountId`** — holdings belong to an account, not directly to an investor
- **Migrate `Transaction` from `InvestorId` → `InvestmentAccountId`; remove `PartyId`** — trades execute against an account; Party is derivable via `PartyInvestmentAccountLink`
- Migrate EF schema (new CRM tables, modified `Investor`/`Holding`/`Transaction` columns, retire `PartyInvestorRelationship`)

---

## Non-Goals

- Frontend UI for the new CRM entities (separate plan)
- Commission module (deferred — `RebateRate` on `AdvisorInvestmentAccountLink` is sufficient for now; see `/docs/crm/taurus_inv_schema_analysis.md` Section 9)
- FATCA/CRS workflow automation (regulatory — Phase 3)
- FrankieOne API integration (store `AmlGatewayReference` as a pointer; actual API calls are out of scope)
- Name versioning / historical name tracking
- NAV pricing or Holdings balance changes (Holdings balance logic is unchanged — only the FK column name changes)
- Modifying the Registry module
- Commission module (deferred)

---

## Architecture

### Layers Touched

| Layer | Changes |
|---|---|
| Domain | New entities: `InvestmentAccount`, `PartyInvestmentAccountLink`, `PartyRelationship`, `AdvisorInvestmentAccountLink`, `InvestorDocument`, `UserPartyLink`, `PartyRoleAssignment`, `IndividualInvestorProfile`, `CorporateInvestorProfile`, `TrustInvestorProfile`. Updated entity: `Investor` (KYC/AML fields, `LegalStructure`, `PartyId` FK), `Party` (`PartyLegalStructure` replaces `PartyType`; `ICollection<PartyRoleAssignment> RoleAssignments` replaces single `PartyFunctionalRole` column). New enums: `PartyLegalStructure`, `PartyFunctionalRole` (incl. `AdvisorRep`; now used in `PartyRoleAssignment.Role`, not on `Party` directly), `InvestmentAccountType`, `InvestmentAccountRelationshipType`, `PartyRelationshipType`, `AmlStatus`, `FatcaCrsStatus`, `DocumentType`, `Gender`. Retire: `PartyType`, `InvestorType`, `PartyInvestorRelationship`. |
| Application | New commands/queries for `InvestmentAccount`, `PartyRelationship`, `AdvisorInvestmentAccountLink`. Updated `Investor` commands. Updated Holdings queries (`GetHoldingsByInvestmentAccount`). Updated Transaction command handlers (`InvestmentAccountId` replaces `InvestorId`/`PartyId`). New ABAC condition template registration. Updated `ICrmReader`. |
| Infrastructure | New EF configurations + migration (CRM + Holdings + Transaction). New repositories. Updated `CrmReader`. |
| Presentation | New endpoints for `InvestmentAccount`, `PartyRelationship`, `AdvisorInvestmentAccountLink`, `InvestorDocument`. Updated Holdings + Transaction endpoints. |
| Abstractions | Updated `ICrmReader` (add `IsInvestmentAccountKycApprovedAsync`). Updated `IHoldingsReader`. New DTOs. |

### New Domain Entities

#### `InvestmentAccount`
```
InvestmentAccount
├── Id (Guid, UUID v7)
├── TenantId (Guid)
├── AccountNumber (string, unique per tenant)
├── InvestmentAccountType (enum: Individual, Joint, Trust, Corporate, SuperannuationFund, Partnership, Other)
├── Status (EntityStatus: Active, Inactive, Locked)
├── CertificateDate (DateOnly?)
├── CreatedBy / UpdatedBy / CreatedAt / UpdatedAt
```

#### `PartyInvestmentAccountLink`  *(replaces `PartyInvestorRelationship`)*
```
PartyInvestmentAccountLink
├── Id (Guid, UUID v7)
├── PartyId (Guid FK → Party)
├── InvestmentAccountId (Guid FK → InvestmentAccount)
├── TenantId (Guid)
├── RelationshipType (InvestmentAccountRelationshipType enum)
├── OwnershipPercentage (decimal?)
├── LinkOrder (int — for joint accounts)
├── EffectiveDate (DateOnly)
├── ExpiryDate (DateOnly?)
├── CreatedBy / UpdatedBy / CreatedAt / UpdatedAt
```

**InvestmentAccountRelationshipType enum:**
`RegisteredHolder = 1, BeneficialHolder = 2, TrustBeneficiary = 3, ControllingEntity = 4, Agent = 5`

#### `PartyRelationship`  *(Party-to-Party)*
```
PartyRelationship
├── Id (Guid, UUID v7)
├── FromPartyId (Guid FK → Party)
├── ToPartyId (Guid FK → Party)
├── TenantId (Guid)
├── RelationshipType (PartyRelationshipType enum)
├── EffectiveDate (DateOnly)
├── ExpiryDate (DateOnly?)
├── CreatedBy / UpdatedBy / CreatedAt / UpdatedAt
```

**PartyRelationshipType enum:**
`ParentFirm = 1, AuthorizedToAdvise = 2, BeneficialOwner = 3, ControllingEntity = 4, TrustBeneficiary = 5`

#### `AdvisorInvestmentAccountLink`
```
AdvisorInvestmentAccountLink
├── Id (Guid, UUID v7)
├── AdvisorPartyId (Guid FK → Party — must have PartyRoleAssignment(AdvisoryFirm) or PartyRoleAssignment(AdvisoryBranch))
├── InvestmentAccountId (Guid FK → InvestmentAccount)
├── TenantId (Guid)
├── RebateRate (decimal?)
├── EffectiveDate (DateOnly)
├── ExpiryDate (DateOnly?)
├── CreatedBy / UpdatedBy / CreatedAt / UpdatedAt
```

#### `InvestorDocument`
```
InvestorDocument
├── Id (Guid, UUID v7)
├── InvestorId (Guid FK → Investor)
├── TenantId (Guid)
├── DocumentType (enum: Passport, DriverLicence, NationalId, BirthCertificate, Other)
├── DocumentNumber (string)
├── IssueCountry (string, ISO 3166-1 alpha-2)
├── IssueState (string?)
├── IssueDate (DateOnly?)
├── ExpiryDate (DateOnly?)
├── CreatedBy / UpdatedBy / CreatedAt / UpdatedAt
```

#### `PartyRoleAssignment`

Replaces the single `PartyFunctionalRole` nullable column on `Party`. A Party can now hold any number of simultaneous functional roles (e.g. AdvisoryRep + Trustee + FundManager). This is the ChatGPT design's `PartyRole` junction table principle — **decouple identity (Party) from behaviour (Role)**.

```
PartyRoleAssignment
├── Id (Guid, UUID v7)
├── TenantId (Guid)
├── PartyId (Guid FK → crm.Parties)
├── Role (PartyFunctionalRole enum)
├── AssignedAt (DateTimeOffset)
├── AssignedBy (Guid — UserId value ref, no cross-schema FK)
├── CreatedBy / UpdatedBy / CreatedAt / UpdatedAt

UNIQUE INDEX (TenantId, PartyId, Role)
```

**Why not a column on `Party`:** A single nullable enum can only store one role. A Party that is simultaneously an `AdvisoryFirm` and a `Distributor`, or an `AdvisorRep` and a `Trustee`, cannot be represented. The junction table handles all multi-role cases cleanly.

**"Investor" is NOT a `PartyFunctionalRole`:** Being an investor is represented by the existence of an `Investor` record with `Investor.PartyId` FK. The `Investor` entity is too rich (KYC/AML, legal structure profiles, FrankieOne) to be a role row. All other service-provider roles (`FundManager`, `Distributor`, `Custodian`, `AdvisoryFirm`, `AdvisoryBranch`, `AdvisorRep`, `Trustee`) live in `PartyRoleAssignment`.

---

#### `UserPartyLink`

Bridges the Auth module's `User` identity to a CRM `Party` record. Enables `ICurrentUser.PartyId` for ABAC evaluation. Stored in CRM — references `UserId` by value only (no cross-schema FK) to preserve module isolation.

```
UserPartyLink
├── Id (Guid, UUID v7)
├── UserId (Guid — value reference to auth.Users, no FK constraint)
├── PartyId (Guid FK → crm.Parties)
├── TenantId (Guid)
├── CreatedBy / UpdatedBy / CreatedAt / UpdatedAt
```

**Indexes:**
- `UNIQUE(TenantId, UserId)` — one Party per User per tenant (a user has exactly one CRM identity per tenant)
- ~~`UNIQUE(TenantId, PartyId)`~~ — **intentionally removed** (see architecture review #3)

**Many-to-one semantics:** Multiple users can link to the same Party. This is required for corporate/institutional parties where multiple authorized staff (CFO, compliance officer) need separate logins but share the same `party_id` JWT claim and therefore the same authorization scope. Individual accountability is preserved via `UserId` in all audit fields. Only `UNIQUE(TenantId, UserId)` is retained — one portal identity per user per tenant.

**Portal generalisation — this pattern covers two use cases:**

| User type | Party they link to | Roles in `PartyRoleAssignment` | Notes |
|---|---|---|---|
| Advisor rep | `Party(Individual)` | `AdvisorRep` | Links to their firm/branch via `PartyRelationship(ParentFirm)` |
| Investor (individual) | `Party(Individual)` | *(none)* | The same Party that `Investor.PartyId` points to |
| Advisor who also invests | `Party(Individual)` | `AdvisorRep` | Also has `Investor(PartyId=...)` — roles are orthogonal |
| Corporate investor staff | `Party(Company)` | *(none or FundManager etc.)* | Multiple users (CFO, compliance) may link to same corporate Party — many-to-one allowed |

When an advisor logs into AdvisorPortal: `ICurrentUser.PartyId` → `UserPartyLink.PartyId` → Party → hierarchy traversal → ABAC.
When an investor logs into InvestorPortal: `ICurrentUser.PartyId` → `UserPartyLink.PartyId` → `Investor.PartyId` → KYC/account data.

**`party_id` claim:**
Set on the JWT at provisioning time (when admin links a User to a Party via `LinkUserToPartyCommand`). `ICurrentUser.PartyId` reads this claim — no DB lookup on every request.

### Updated: `Investor` — KYC/AML Enrichment + Legal-Structure Discriminator

`Investor` is the **base entity** for all legal-structure profile types. It carries fields common to **every** investor regardless of legal structure, plus a `LegalStructure` discriminator pointing to the relevant extension table.

**Discriminator (replaces `InvestorType`):**
- `LegalStructure` (enum: `Individual=1, Company=2, Trust=3, SuperFund=4`)

**Tax & Compliance (all structures):**
- `TaxResidencyCountry` (string?, ISO alpha-2)
- `TIN` (string?) — Tax Identification Number
- `FatcaCrsStatus` (enum: NotReviewed, Compliant, Exempt, ReportingRequired)
- `GIIN` (string?) — FATCA Global Intermediary ID

**AML / Identity Verification (all structures):**
- `AmlStatus` (enum: NotChecked, Clear, Review, Blocked)
- `AmlGatewayReference` (string?) — FrankieOne `entityId` pointer
- `AmlCheckedAt` (DateTimeOffset?)
- `IsPEP` (bool?)
- `PepDetails` (string?)
- `SourceOfWealth` (string?)
- `UnresolvedPepCount` (int)
- `UnresolvedSanctionCount` (int)
- `UnresolvedAdverseMediaCount` (int)

**Navigation to extension tables (at most one non-null, matched by `LegalStructure`):**
- `IndividualProfile` → `IndividualInvestorProfile?`
- `CorporateProfile` → `CorporateInvestorProfile?`
- `TrustProfile` → `TrustInvestorProfile?`

> `InvestorType` (Individual/Corporate/Institutional) is retired; `LegalStructure` is its replacement.

---

### Legal-Structure Profile Design: Extension Tables (Composition Pattern)

Different legal structures require fundamentally different profile fields. EF inheritance strategies are avoided: TPH creates nullable sprawl and can't enforce NOT NULL per type; EF TPT generates poor SQL with UNIONs; TPC breaks FK references to the abstract base. Instead we use **explicit composition** — each legal structure gets its own extension entity linked by a 1:0-1 FK to `Investor`.

```
crm.Investors                         ← base (KYC, AML, tax, LegalStructure discriminator)
  ├── crm.IndividualInvestorProfiles   ← 1:0-1, InvestorId FK UNIQUE
  ├── crm.CorporateInvestorProfiles    ← 1:0-1, InvestorId FK UNIQUE
  ├── crm.TrustInvestorProfiles        ← 1:0-1, InvestorId FK UNIQUE
  └── (future) crm.SuperFundInvestorProfiles
```

Adding a new legal structure = new entity + new table only. Zero changes to `Investor` or existing profiles.

#### `IndividualInvestorProfile`
```
IndividualInvestorProfile
├── Id (Guid, UUID v7)
├── InvestorId (Guid FK → Investor, UNIQUE)
├── DateOfBirth (DateOnly?)
├── DateOfDeath (DateOnly?)
├── Gender (enum: Male, Female, Unspecified, Other)
├── PlaceOfBirth (string?)
├── Nationality (string?, ISO alpha-2)
├── IdDocumentType (string?)       — primary KYC document type for quick access
├── IdDocumentNumber (string?)
├── IdDocumentCountry (string?, ISO alpha-2)
├── IdDocumentExpiry (DateOnly?)
├── FrankieOneEntityId (string?)
```

#### `CorporateInvestorProfile`
```
CorporateInvestorProfile
├── Id (Guid, UUID v7)
├── InvestorId (Guid FK → Investor, UNIQUE)
├── Acn (string?)                  — AU Company Number
├── Abn (string?)                  — AU Business Number
├── RegistrationNumber (string?)   — non-AU equivalent
├── CountryOfIncorporation (string?, ISO alpha-2)
├── IncorporationDate (DateOnly?)
├── IsPubliclyListed (bool?)
├── Regulator (string?)
├── LicenceNumber (string?)
├── FrankieOneEntityId (string?)
```

#### `TrustInvestorProfile`
```
TrustInvestorProfile
├── Id (Guid, UUID v7)
├── InvestorId (Guid FK → Investor, UNIQUE)
├── TrustType (string?)            — Discretionary, Unit, SMSF, Hybrid…
├── TrustDeedReference (string?)
├── TrustEstablishedDate (DateOnly?)
├── TrusteePartyId (Guid? FK → Party)   — trustee is a registered legal entity (Party)
├── FrankieOneEntityId (string?)
```

#### EF Core Configuration (per extension entity)
```csharp
builder.HasOne(x => x.IndividualProfile)
    .WithOne(p => p.Investor)
    .HasForeignKey<IndividualInvestorProfile>(p => p.InvestorId)
    .IsRequired(false);
// Repeat for CorporateProfile, TrustProfile
```

#### Query Strategy — load only the matching extension
```csharp
IQueryable<Investor> q = _db.Investors.Where(i => i.Id == id);
q = investor.LegalStructure switch {
    PartyLegalStructure.Individual => q.Include(i => i.IndividualProfile),
    PartyLegalStructure.Company    => q.Include(i => i.CorporateProfile),
    PartyLegalStructure.Trust      => q.Include(i => i.TrustProfile),
    _                              => q
};
```

List/summary views query the `Investors` base table only — no joins needed.

#### Scaling to Functional Role Profiles (Future)
Same pattern: `FundManagerProfile`, `DistributorProfile`, etc. carry a `PartyId` FK and a 1:0-1 navigation on `Party`. Zero changes to `Party`, `PartyRoleAssignment`, or any existing profile entity.

---

### Two-Layer Advisor Authorization (ABAC)

**Layer 1 — Can create investment for investor X:**
```
PartyRelationship(FromPartyId=advisorPartyId, ToPartyId=investorPartyId,
                  Type=AuthorizedToAdvise, isActive=true)
```
OPA condition template: `HasAdvisoryAuthorization(advisorPartyId, investorPartyId)`

**Layer 2 — Can manage investment account Y:**
```
AdvisorInvestmentAccountLink(AdvisorPartyId=advisorPartyId, InvestmentAccountId=accountId, isActive=true)
```
OPA condition template: `IsAdvisorForAccount(advisorPartyId, accountId)`

Both templates must traverse the Party hierarchy (rep → branch → firm) via `PartyRelationship(ParentFirm)`.

### New API Endpoints

**InvestmentAccount:**
- `GET /api/v1/investment-account` — list (tenant-scoped)
- `GET /api/v1/investment-account/{id}`
- `POST /api/v1/investment-account`
- `PUT /api/v1/investment-account/{id}`
- `DELETE /api/v1/investment-account/{id}` (soft-delete: Status = Inactive)
- `GET /api/v1/investment-account/{id}/parties` — list linked parties
- `POST /api/v1/investment-account/{id}/parties` — link party (PartyInvestmentAccountLink)
- `DELETE /api/v1/investment-account/{id}/parties/{partyId}` — unlink party

**PartyRelationship:**
- `GET /api/v1/party/{id}/relationships` — list relationships for a party
- `POST /api/v1/party/{id}/relationships` — create relationship
- `DELETE /api/v1/party/{id}/relationships/{relId}` — expire/remove relationship

**AdvisorInvestmentAccountLink:**
- `GET /api/v1/investment-account/{id}/advisors` — list advisors for account
- `POST /api/v1/investment-account/{id}/advisors` — link advisor
- `DELETE /api/v1/investment-account/{id}/advisors/{advisorPartyId}` — unlink advisor

**InvestorDocument:**
- `GET /api/v1/investor/{id}/documents`
- `POST /api/v1/investor/{id}/documents`
- `DELETE /api/v1/investor/{id}/documents/{docId}`

### Updated `ICrmReader`

```csharp
// Existing (unchanged)
Task<PartySummaryDto?>    GetPartyByIdAsync(Guid partyId, Guid tenantId, CancellationToken ct);
Task<InvestorSummaryDto?> GetInvestorByIdAsync(Guid investorId, Guid tenantId, CancellationToken ct);
Task<bool>                IsInvestorKycApprovedAsync(Guid investorId, Guid tenantId, CancellationToken ct);
Task<bool>                PartyExistsAsync(Guid partyId, Guid tenantId, CancellationToken ct);

// New additions
Task<InvestmentAccountSummaryDto?> GetInvestmentAccountByIdAsync(Guid accountId, Guid tenantId, CancellationToken ct);
Task<bool>                         InvestmentAccountExistsAsync(Guid accountId, Guid tenantId, CancellationToken ct);
Task<bool>                         AdvisorIsAuthorizedForInvestorAsync(Guid advisorPartyId, Guid investorPartyId, Guid tenantId, CancellationToken ct);
Task<bool>                         IsPartyKycApprovedAsync(Guid partyId, Guid tenantId, CancellationToken ct);
Task<bool>                         IsInvestmentAccountKycApprovedAsync(Guid accountId, Guid tenantId, CancellationToken ct);
```

`IsInvestmentAccountKycApprovedAsync` resolves: `accountId → PartyInvestmentAccountLink(RegisteredHolder) → Party → Investor.KycStatus = Approved`. Used by Transaction command handlers to validate KYC before processing a trade.

---

### Updated: `Holding` entity (Holdings module)

`InvestorId` is replaced by `InvestmentAccountId`. Holdings belong to an account — not directly to an investor — because joint accounts, trust accounts, and multiple-account investors all break the 1:1 assumption that `InvestorId` implied.

```
holdings.Holdings
├── Id, TenantId
├── InvestmentAccountId  (Guid — value ref to crm.InvestmentAccounts, no cross-schema FK)  ← replaces InvestorId
├── ClassId              (Guid — value ref to registry.FundClasses)
├── Units
├── Status, LastTransactionAt
└── Audit fields
```

**Uniqueness constraint:**
```
UNIQUE(TenantId, InvestmentAccountId, ClassId)
```
Enforces exactly one position row per account/class. Without this, a double-processed transaction event could silently create two rows, splitting the unit balance and corrupting any query that reads a single position. `Holding` is a current-state view (no lot tracking) — one row per (Account, Class) is the invariant.

**Query changes:**
- `GetHoldingsByInvestmentAccountQuery` — primary query (direct FK lookup)
- `GET /api/v1/investor/{investorId}/holdings` — convenience endpoint kept; resolves `investorId → Party → PartyInvestmentAccountLinks → accounts → holdings` at the application layer

---

### Updated: `Transaction` entity (Transaction module)

`InvestorId` replaced by `InvestmentAccountId`; `PartyId` removed — the account holder Party is derivable via `PartyInvestmentAccountLink(RegisteredHolder)` and should not be denormalised onto the Transaction.

```
transaction.Transactions
├── Id, TenantId
├── Type  (Subscription / Redemption / Transfer / Switch)
├── InvestmentAccountId  (Guid — value ref to crm.InvestmentAccounts)  ← replaces InvestorId + PartyId
├── FundId, ClassId
├── TargetClassId (Transfer / Switch only)
├── Amount, Units, NAVPrice
├── TradeDate, SettlementDate
├── Status, FailureReason
└── Audit fields
```

**Factory method signatures (updated):**
```csharp
Transaction.CreateSubscription(tenantId, investmentAccountId, fundId, classId, amount, tradeDate)
Transaction.CreateRedemption(tenantId, investmentAccountId, fundId, classId, amount, tradeDate)
Transaction.CreateTransfer(tenantId, investmentAccountId, fundId, classId, targetClassId, amount, tradeDate)
Transaction.CreateSwitch(tenantId, investmentAccountId, fundId, classId, targetClassId, amount, tradeDate)
```

**KYC validation (updated):**
Transaction command handlers call `IsInvestmentAccountKycApprovedAsync(accountId, tenantId)` instead of `IsInvestorKycApprovedAsync(investorId, tenantId)`.

### EF Schema Changes

- **New tables:** `crm.InvestmentAccounts`, `crm.PartyInvestmentAccountLinks`, `crm.PartyRelationships`, `crm.AdvisorInvestmentAccountLinks`, `crm.InvestorDocuments`, `crm.UserPartyLinks`, `crm.PartyRoleAssignments`
- **New extension tables:** `crm.IndividualInvestorProfiles`, `crm.CorporateInvestorProfiles`, `crm.TrustInvestorProfiles` — each with `InvestorId UNIQUE FK` + CASCADE DELETE
- **Modified table:** `crm.Parties` — drop `PartyType`; add `LegalStructure` (tinyint NOT NULL, back-filled); **no** `FunctionalRole` column — roles live in `crm.PartyRoleAssignments`
- **Modified table:** `crm.Investors` — rename `InvestorType` → `LegalStructure`; add `PartyId` (nullable FK → Parties); add KYC/AML columns
- **Modified table:** `holdings.Holdings` — rename `InvestorId` → `InvestmentAccountId`
- **Modified table:** `transaction.Transactions` — rename `InvestorId` → `InvestmentAccountId`; drop `PartyId` column
- **Retire:** `crm.PartyInvestorRelationships` — clean drop (zero rows confirmed pre-migration)
- **New unique indexes:** `UserPartyLinks(TenantId, UserId)` *(no `UserPartyLinks(TenantId, PartyId)` — many-to-one allowed)*, `InvestmentAccounts(TenantId, AccountNumber)`, `PartyRelationships(FromPartyId, ToPartyId, RelationshipType)` (partial: ExpiryDate IS NULL), `IndividualInvestorProfiles(InvestorId)`, `CorporateInvestorProfiles(InvestorId)`, `TrustInvestorProfiles(InvestorId)`, `Investors(TenantId, PartyId)` (filtered: PartyId IS NOT NULL), `PartyRoleAssignments(TenantId, PartyId, Role)`, `Holdings(TenantId, InvestmentAccountId, ClassId)` — prevents duplicate position rows per account/class

---

## Implementation Steps

### Phase 1 — Domain (no external dependencies)
- [ ] Add `PartyLegalStructure` enum (Individual=1, Company=2, Trust=3, SuperFund=4) — replaces `PartyType` on `Party`
- [ ] Add `PartyFunctionalRole` enum (FundManager=1, Distributor=2, Custodian=3, TransferAgent=4, AdvisoryFirm=5, AdvisoryBranch=6, AdvisorRep=7, Trustee=8) — used as `Role` field in `PartyRoleAssignment`; **no longer a column on `Party`**
- [ ] Retire `PartyType` enum — remove after `Party` entity migration
- [ ] Update `Party` entity: replace `PartyType` with `PartyLegalStructure` (required); add `ICollection<PartyRoleAssignment> RoleAssignments` navigation property; remove any `PartyFunctionalRole` field; update factory `Create(...)` and `Update(...)` signatures accordingly
- [ ] Create `PartyRoleAssignment` entity with factory method `Assign(tenantId, partyId, role, assignedBy)`; add `IPartyRoleAssignmentRepository` with `GetRolesForPartyAsync(partyId, tenantId)` and `HasRoleAsync(partyId, role, tenantId)`
- [ ] Add `InvestmentAccountRelationshipType` enum (RegisteredHolder, BeneficialHolder, TrustBeneficiary, ControllingEntity, Agent)
- [ ] Add `PartyRelationshipType` enum (ParentFirm, AuthorizedToAdvise, BeneficialOwner, ControllingEntity, TrustBeneficiary)
- [ ] Add `InvestmentAccountType` enum (Individual, Joint, Trust, Corporate, SuperannuationFund, Partnership, Other)
- [ ] Add `AmlStatus` enum (NotChecked, Clear, Review, Blocked)
- [ ] Add `FatcaCrsStatus` enum (NotReviewed, Compliant, Exempt, ReportingRequired)
- [ ] Add `DocumentType` enum (Passport, DriverLicence, NationalId, BirthCertificate, Other)
- [ ] Add `Gender` enum (Male, Female, Unspecified, Other)
- [ ] Create `InvestmentAccount` entity with factory method `Create(...)` and `Update(...)`, `Deactivate()`, `Lock()`
- [ ] Create `PartyInvestmentAccountLink` entity with factory method
- [ ] Create `PartyRelationship` entity with factory method and `Expire()` method
- [ ] Create `AdvisorInvestmentAccountLink` entity with factory method and `Expire()` method
- [ ] Create `InvestorDocument` entity with factory method
- [ ] Update `Investor` entity: replace `InvestorType` with `LegalStructure` (`PartyLegalStructure`); add common KYC/AML fields; add `UpdateKycEnriched(...)`, `UpdateAmlStatus(...)` methods; add navigation properties to extension profiles
- [ ] Create `IndividualInvestorProfile` entity with factory method (Individual-specific fields: DOB, gender, nationality, primary ID document, FrankieOneEntityId)
- [ ] Create `CorporateInvestorProfile` entity with factory method (Company-specific fields: ACN, ABN, registration, country of incorporation, publicly listed, FrankieOneEntityId)
- [ ] Create `TrustInvestorProfile` entity with factory method (Trust-specific fields: trust type, deed reference, TrusteePartyId FK, FrankieOneEntityId)
- [ ] Add repository interfaces: `IInvestmentAccountRepository`, `IPartyInvestmentAccountLinkRepository`, `IPartyRelationshipRepository`, `IAdvisorInvestmentAccountLinkRepository`, `IInvestorDocumentRepository`
- [ ] Add `IIndividualInvestorProfileRepository`, `ICorporateInvestorProfileRepository`, `ITrustInvestorProfileRepository` (create/update operations for extension profiles)
- [ ] Add `GetLinksByAccountIdAsync(accountId, tenantId)` to `IPartyInvestmentAccountLinkRepository` (needed by Q1 validator)
- [ ] Create `UserPartyLink` entity with factory method; `IUserPartyLinkRepository` with `GetByUserIdAsync(userId, tenantId)` and `GetByPartyIdAsync(partyId, tenantId)`
- [ ] Update `AdvisoryAuthorizationTemplate`: replace `party.PartyFunctionalRole == AdvisoryRep` check with `await _roleRepo.HasRoleAsync(partyId, PartyFunctionalRole.AdvisorRep, tenantId, ct)`
- [ ] Remove `PartyInvestorRelationship` entity and `IPartyInvestorRepository`
- [ ] **Holdings.Domain:** update `Holding` entity — rename `InvestorId` to `InvestmentAccountId`; update `Create(...)` factory method signature
- [ ] **Transaction.Domain:** update `Transaction` entity — rename `InvestorId` to `InvestmentAccountId`; remove `PartyId`; update all four factory method signatures
- [ ] Create `AdvisoryAuthorizationTemplate` condition template (Q2 decision) — traverses `PartyRelationship(ParentFirm)` chain up to depth 3; per-request in-memory cache on `(advisorPartyId, investorPartyId, tenantId)`

### Phase 2 — Application (CQRS handlers + ABAC)
- [ ] **InvestmentAccount commands:** `CreateInvestmentAccountCommand`, `UpdateInvestmentAccountCommand`, `DeleteInvestmentAccountCommand`
- [ ] **InvestmentAccount queries:** `GetInvestmentAccountsQuery`, `GetInvestmentAccountByIdQuery`, `GetInvestmentAccountsByPartyQuery`
- [ ] **PartyInvestmentAccountLink commands:** `LinkPartyToInvestmentAccountCommand`, `UnlinkPartyFromInvestmentAccountCommand`
- [ ] **PartyRelationship commands:** `CreatePartyRelationshipCommand`, `ExpirePartyRelationshipCommand`
- [ ] **PartyRelationship queries:** `GetPartyRelationshipsQuery` (by FromPartyId or ToPartyId)
- [ ] **Direction guard:** Add directional semantics to `PartyRelationshipType` enum via XML doc comments (e.g. `/// FromParty belongs to ToParty` for `ParentFirm`; `/// FromParty is authorised to advise ToParty` for `AuthorizedToAdvise`); add `CreatePartyRelationshipCommandValidator` guards that enforce correct role-per-direction (e.g. `ParentFirm` requires `FromParty` has `AdvisorRep` or `AdvisoryBranch` role; `AuthorizedToAdvise` requires `FromParty` has an advisory role; `BeneficialOwner` and `ControllingEntity` require `FromParty` is an individual or company respectively)
- [ ] **AdvisorInvestmentAccountLink commands:** `LinkAdvisorToInvestmentAccountCommand`, `UnlinkAdvisorFromInvestmentAccountCommand`
- [ ] **AdvisorInvestmentAccountLink queries:** `GetAdvisorsForInvestmentAccountQuery`
- [ ] **InvestorDocument commands:** `AddInvestorDocumentCommand`, `RemoveInvestorDocumentCommand`
- [ ] **InvestorDocument queries:** `GetInvestorDocumentsQuery`
- [ ] **Investor create:** extend `CreateInvestorCommand` to require `LegalStructure` + accept type-specific profile fields (individual/corporate/trust sub-object); handler creates `Investor` + the matching extension profile in one transaction
- [ ] **Investor update:** extend `UpdateInvestorCommand` with new KYC fields + type-specific profile fields; add `UpdateInvestorAmlCommand`
- [ ] **PartyRoleAssignment commands:** `AssignPartyRoleCommand`, `RemovePartyRoleCommand` — admin operation; validates Party exists and role not already assigned/not assigned
- [ ] **PartyRoleAssignment queries:** `GetPartyRolesQuery(partyId)` — returns all active role assignments for a party
- [ ] **UserPartyLink commands:** `LinkUserToPartyCommand`, `UnlinkUserFromPartyCommand` — admin operation; sets/clears `party_id` claim on the User via `IIdentityProvider.UpdateUserClaimsAsync`
- [ ] **UserPartyLink queries:** `GetPartyForUserQuery` — resolves `UserId → PartyId` (used by AdvisorPortal/InvestorPortal on login)
- [ ] **Holdings.Application:** add `GetHoldingsByInvestmentAccountQuery`; update `GetHoldingsByInvestorQuery` to resolve via `investorId → Party → accounts → holdings` (convenience wrapper)
- [ ] **Transaction.Application:** update all four `Create*Command` handlers to use `InvestmentAccountId`; replace `IsInvestorKycApprovedAsync` call with `IsInvestmentAccountKycApprovedAsync`; remove `PartyId` from command/DTO
- [ ] Remove `LinkInvestorToPartyCommand` and `UnlinkInvestorFromPartyCommand`
- [ ] Register ABAC condition templates: `HasAdvisoryAuthorization` (uses `AdvisoryAuthorizationTemplate`), `IsAdvisorForAccount` in `BuiltInTemplates`
- [ ] **Q1:** add joint-account and ownership% validators to `LinkPartyToInvestmentAccountCommandValidator`
- [ ] Add `PolicyDefinition` seeds for new resource types (`investment-account`, `party-relationship`, `advisor-investment-account-link`, `investor-document`) in ABAC policy seeder
- [ ] Add FluentValidation validators for all new commands
- [ ] Add AutoMapper mappings for new DTOs

### Phase 3 — Infrastructure (EF + Repositories)
- [ ] Add EF entity configurations for `InvestmentAccount`, `PartyInvestmentAccountLink`, `PartyRelationship`, `AdvisorInvestmentAccountLink`, `InvestorDocument`
- [ ] Update `Party` EF configuration: remove `PartyType`; add `LegalStructure` (required, tinyint); configure `HasMany(p => p.RoleAssignments).WithOne(r => r.Party).HasForeignKey(r => r.PartyId).OnDelete(DeleteBehavior.Cascade)`
- [ ] Add EF entity configuration for `PartyRoleAssignment` (`ToTable("PartyRoleAssignments", "crm")`; UNIQUE index on `(TenantId, PartyId, Role)`); implement `EfPartyRoleAssignmentRepository`
- [ ] Update `Investor` EF configuration: rename `InvestorType` column to `LegalStructure`; add `PartyId` nullable FK + filtered UNIQUE index `(TenantId, PartyId) WHERE PartyId IS NOT NULL`; add KYC/AML columns; configure 1:0-1 HasOne/WithOne navigations for `IndividualProfile`, `CorporateProfile`, `TrustProfile`
- [ ] Add EF entity configurations for `IndividualInvestorProfile`, `CorporateInvestorProfile`, `TrustInvestorProfile` (each: `ToTable`, `HasKey`, `HasOne/WithOne`, UNIQUE index on `InvestorId`)
- [ ] Add EF entity configuration for `UserPartyLink` (`ToTable("UserPartyLinks", "crm")`; UNIQUE index on `(TenantId, UserId)` only — no unique index on `(TenantId, PartyId)` — many-to-one is intentional)
- [ ] Implement `EfUserPartyLinkRepository`
- [ ] Remove `PartyInvestorRelationship` EF configuration
- [ ] Implement `EfInvestmentAccountRepository`, `EfPartyInvestmentAccountLinkRepository`, `EfPartyRelationshipRepository`, `EfAdvisorInvestmentAccountLinkRepository`, `EfInvestorDocumentRepository`
- [ ] Update `CrmDbContext` (add DbSets, remove `PartyInvestorRelationships`)
- [ ] Update `CrmReader` to implement new `ICrmReader` methods
- [ ] **Q3:** Confirm `SELECT COUNT(*) FROM crm.PartyInvestorRelationships` = 0 on all non-production environments before cutting migration
- [ ] **Holdings.Infrastructure:** update `HoldingConfiguration` — rename column `InvestorId` → `InvestmentAccountId`; add `UNIQUE(TenantId, InvestmentAccountId, ClassId)` index; update `EfHoldingRepository` queries
- [ ] **Transaction.Infrastructure:** update `TransactionConfiguration` — rename `InvestorId` → `InvestmentAccountId`; drop `PartyId` column mapping; update `EfTransactionRepository` queries
- [ ] Write EF migration (single migration across all three DB contexts or coordinated migrations): create new CRM tables, alter `crm.Investors`, drop `crm.PartyInvestorRelationships`, rename `holdings.Holdings.InvestorId` → `InvestmentAccountId`, rename `transaction.Transactions.InvestorId` → `InvestmentAccountId` + drop `PartyId`
- [ ] Verify `NoOpAbacPolicyCache` still compiles (no changes expected)

### Phase 4 — Presentation (Endpoints)
- [ ] `InvestmentAccountEndpoints`: CRUD + party link/unlink + advisor link/unlink
- [ ] `PartyRoleEndpoints`: `GET /api/v1/party/{id}/roles`, `POST /api/v1/party/{id}/roles`, `DELETE /api/v1/party/{id}/roles/{role}`
- [ ] `PartyRelationshipEndpoints`: create + list + expire
- [ ] `AdvisorInvestmentAccountLinkEndpoints`: link / unlink / list (mounted under investment-account)
- [ ] `InvestorDocumentEndpoints`: add / list / remove
- [ ] `UserPartyLinkEndpoints`: link user to party + unlink + get party for user
- [ ] **Holdings.Presentation:** add `GET /api/v1/investment-account/{accountId}/holdings` endpoint; update `GET /api/v1/investor/{investorId}/holdings` to resolve through accounts
- [ ] **Transaction.Presentation:** update all Create* request DTOs to replace `investorId`/`partyId` with `investmentAccountId`
- [ ] Remove `RelationshipEndpoints` (old LinkInvestor/UnlinkInvestor)
- [ ] Update request/response DTOs

### Phase 5 — Abstractions
- [ ] Add `InvestmentAccountSummaryDto` to `CRM.Abstractions`
- [ ] Update `ICrmReader` interface: add `IsPartyKycApprovedAsync`, `IsInvestmentAccountKycApprovedAsync`, and other new methods
- [ ] Update `PartySummaryDto`: replace `PartyType` field with `LegalStructure` + `Roles` (list of `PartyFunctionalRole`)
- [ ] Update `HoldingSummaryDto`: replace `InvestorId` field with `InvestmentAccountId`
- [ ] Update `IHoldingsReader`: replace `GetHoldingsByInvestorAsync(investorId)` with `GetHoldingsByInvestmentAccountAsync(accountId)`
- [ ] Add `InvestmentAccountCreatedEvent`, `PartyRelationshipCreatedEvent` integration events
- [ ] Update `CrmReader` implementation for new interface methods

### Phase 6 — Tests
- [ ] Unit tests: `CreateInvestmentAccountCommandHandlerTests`
- [ ] Unit tests: `CreatePartyRelationshipCommandHandlerTests`
- [ ] Unit tests: `LinkAdvisorToAccountCommandHandlerTests`
- [ ] Unit tests: `AddInvestorDocumentCommandHandlerTests`
- [ ] Unit tests: `UpdateInvestorAmlCommandHandlerTests`
- [ ] Unit tests: `InvestmentAccount` domain entity factory + lifecycle
- [ ] Unit tests: `PartyRelationship` domain entity factory + Expire()
- [ ] Unit tests: `AdvisorInvestmentAccountLink` factory + Expire()
- [ ] Unit tests: `Investor` entity KYC/AML field updates
- [ ] Review and update existing `CreatePartyCommandHandlerTests`, `CreateInvestorCommandHandlerTests`, `UpdateInvestorKycCommandHandlerTests`
- [ ] Update all Holdings query handler tests: replace `InvestorId` with `InvestmentAccountId` in test fixtures
- [ ] Update all Transaction command handler tests: replace `investorId`/`partyId` params with `investmentAccountId`; update KYC mock to use `IsInvestmentAccountKycApprovedAsync`

### Phase 7 — Docs + CLAUDE.md
- [ ] Update `CLAUDE.md` Quick Reference (API endpoints, test counts)
- [ ] Update `/docs/crm/crm_advisor_design_discussion.md` status to reflect decisions implemented
- [ ] Add plan entry to `CLAUDE.md` Instruction Index

---

## Testing Plan

### Unit Tests
- All new command handlers: happy path + validation failures + not-found + tenant mismatch
- Domain entity factory methods: guard clauses (empty IDs, null strings)
- `Expire()` methods: idempotent on already-expired relationships

### Integration Tests (manual via HTTP / Swagger)
- Create `Party(LegalStructure=Company)` → `AssignPartyRole(AdvisoryFirm)` → create `Party(LegalStructure=Company)` → `AssignPartyRole(AdvisoryBranch)` → create `PartyRelationship(ParentFirm)` between them
- Create `Party(LegalStructure=Individual)` → create `Investor(PartyId=..., LegalStructure=Individual)` with `IndividualInvestorProfile`
- Create `InvestmentAccount` → link via `PartyInvestmentAccountLink(PartyId=investor.PartyId, RelationshipType=RegisteredHolder)`
- Create `PartyRelationship(AuthorizedToAdvise)` from AdvisoryFirm → Investor's Party
- Link AdvisoryFirm to `InvestmentAccount` via `AdvisorInvestmentAccountLink`
- Attempt to create a second `InvestmentAccount` for the same investor with a different Advisor — verify both are permitted
- Expire `AdvisorInvestmentAccountLink` → verify advisor can no longer manage account (ABAC deny)
- Add `InvestorDocument` → list documents → remove document
- Update `Investor` AML status → verify `AmlStatus`, `AmlGatewayReference`, `AmlCheckedAt` persisted

### Regression
- Existing Party CRUD endpoints unchanged
- Existing Investor CRUD endpoints unchanged (new KYC fields are nullable/optional)
- `ICrmReader` callers compile and pass — `IsInvestorKycApprovedAsync` kept (not removed); new `IsInvestmentAccountKycApprovedAsync` added alongside it
- Holdings read endpoints return correct data after `InvestorId → InvestmentAccountId` rename
- Transaction create endpoints accept `investmentAccountId` in request body; no `investorId`/`partyId` required

---

## Decisions

---

### Q1 — Joint Accounts: `PartyInvestmentAccountLink.LinkOrder` uniqueness ✅ DECIDED: Option B

**Decision:** Application-layer validation only. No DB unique index.

Enforce in `LinkPartyToInvestmentAccountCommandValidator`:
1. Query existing `PartyInvestmentAccountLinks` for the account via `GetLinksByAccountIdAsync(accountId, tenantId)`.
2. If `LinkOrder` is provided and another link already has the same value on the same account → reject: `"LinkOrder {n} is already assigned to another party on this account."`.
3. If `InvestmentAccountType != Joint` and `RelationshipType = RegisteredHolder` and a RegisteredHolder already exists → reject: `"A non-joint account may only have one RegisteredHolder."`.
4. If `OwnershipPercentage` is provided and the sum across all `RegisteredHolder` links exceeds 100% → reject: `"Total ownership percentage cannot exceed 100%."` (warn, not error, when less than 100% — partial ownership is valid during account setup).

**Why Option B over A:** Consistent with how all other IFX business rules are enforced (application layer, not DB constraints). No external tooling writes directly to these tables, so bypass risk is negligible.

**Implementation note:** Add `GetLinksByAccountIdAsync(accountId, tenantId)` to `IPartyInvestmentAccountLinkRepository`.

---

### Q2 — ABAC Traversal: C# Condition Template or OPA Rego ✅ DECIDED: Option A

**Decision:** C# condition template (`AdvisoryAuthorizationTemplate`).

Create `AdvisoryAuthorizationTemplate : IConditionTemplate` in `IFX.BuildingBlocks.Security`:

```csharp
// Registered as: "HasAdvisoryAuthorization"
// Resource attributes must carry: AdvisorPartyId, InvestorPartyId, TenantId
public class AdvisoryAuthorizationTemplate(IPartyRelationshipReader reader) : IConditionTemplate
{
    public async Task<bool> EvaluateAsync(AbacCondition condition, ClaimsPrincipal subject,
                                          IResourceAttributes resource, CancellationToken ct)
    {
        var attrs = (AdvisoryResourceAttributes)resource;
        return await reader.HasAdvisoryAuthorizationAsync(
            attrs.AdvisorPartyId, attrs.InvestorPartyId, attrs.TenantId, ct);
    }
}
```

`IPartyRelationshipReader.HasAdvisoryAuthorizationAsync` traversal logic:
1. Check direct `PartyRelationship(AuthorizedToAdvise)` from `advisorPartyId` → `investorPartyId`.
2. If not found, find `PartyRelationship(ParentFirm)` where `ToPartyId = advisorPartyId` → recurse on `FromPartyId` (max depth 3).
3. Per-request in-memory cache keyed on `(advisorPartyId, investorPartyId, tenantId)` to prevent N+1 queries.

Register in `CrmModuleInstaller`. Expose `IPartyRelationshipReader` via `CRM.Abstractions`.

**Why Option A over B/C:** OPA cannot query the DB — passing the full hierarchy through `input` JSON couples hierarchy-loading to every call site. The C# template keeps all traversal logic in one testable place, consistent with `SameTenant` and `CreatedByMe` patterns.

---

### Q3 — `PartyInvestorRelationship` data migration ✅ DECIDED: Clean drop

**Decision:** Write EF migration as clean create + drop with no data copy.

```csharp
// Migration Up():
migrationBuilder.DropTable(name: "PartyInvestorRelationships", schema: "crm");
migrationBuilder.CreateTable(name: "InvestmentAccounts", schema: "crm", ...);
migrationBuilder.CreateTable(name: "PartyInvestmentAccountLinks", schema: "crm", ...);
// ... remaining new tables
```

Safe because:
- Feature branch never deployed to production — no production rows exist ✅
- `InitialSeed` migration has no `PartyInvestorRelationship` seed rows ✅
- `Transaction.Application` references `ICrmReader` only — no cross-module impact ✅

**Pre-migration gate (added to Phase 3):** Run `SELECT COUNT(*) FROM crm.PartyInvestorRelationships` on all non-production environments and confirm zero before executing migration.

**Phase 6 note:** Update any integration tests referencing `LinkInvestorToPartyCommand` / `UnlinkInvestorFromPartyCommand` to use `LinkPartyToInvestmentAccountCommand`.

---

### Q4 — `Investor` Identity vs `Party` Identity ✅ DECIDED: Path 2

**Decision:** Add `PartyId` FK to `Investor`; split `PartyType` on `Party` into `PartyLegalStructure` (mandatory) + `PartyFunctionalRole` (nullable).

---

#### The Problem

Currently `Party` and `Investor` are independent with no FK. `PartyInvestmentAccountLink.PartyId` can only reference service providers (FundManager, Distributor, etc.) — not individuals — because individuals are recorded as `Investor`, not `Party`. KYC checks use `Investor.Id`; account links use `Party.Id`. There is no formal bridge.

---

#### Path 2 Design

**`Party` entity changes:**
- Add `PartyLegalStructure` (enum, **required**) — what the party **is** (legal structure)
- Remove `PartyType` — replaced by `PartyLegalStructure` + `PartyRoleAssignment` table (see below)
- No `PartyFunctionalRole` column on `Party` — role multiplicity is handled by the `PartyRoleAssignment` junction table

`PartyLegalStructure` enum: `Individual=1, Company=2, Trust=3, SuperFund=4`

`PartyFunctionalRole` enum (used in `PartyRoleAssignment.Role`):
`FundManager=1, Distributor=2, Custodian=3, TransferAgent=4, AdvisoryFirm=5, AdvisoryBranch=6, AdvisorRep=7, Trustee=8`

> **Note:** `Trustee=8` is added to explicitly support parties that act as trustee for a managed fund or trust structure — separate from `TrustInvestorProfile.TrusteePartyId` which is a Party reference within a trust's KYC profile.

Examples after migration:
| Old `PartyType` | `PartyLegalStructure` | `PartyRoleAssignment(s)` |
|---|---|---|
| FundManager | Company | `FundManager` |
| Distributor | Company | `Distributor` |
| Custodian | Company | `Custodian` |
| TransferAgent | Company | `TransferAgent` |
| AdvisoryFirm | Company | `AdvisoryFirm` |
| AdvisoryBranch | Company | `AdvisoryBranch` |
| Other | Company | *(none)* |
| *(new)* Individual investor | Individual | *(none — `Investor` record covers this)* |
| *(new)* Trust investor | Trust | *(none)* |
| *(new)* Advisor + Investor | Individual | `AdvisorRep` |
| *(new)* Advisor + Trustee | Individual | `AdvisorRep`, `Trustee` |

**`Investor` entity changes:**
- Add `PartyId` (Guid?, nullable FK → `crm.Parties`) — links KYC profile to universal legal identity
- Add filtered UNIQUE index: `UNIQUE(TenantId, PartyId) WHERE PartyId IS NOT NULL` — enforces one Investor profile per Party per tenant (one-to-zero-or-one)

**`ICrmReader` additions:**
```csharp
Task<bool> IsPartyKycApprovedAsync(Guid partyId, Guid tenantId, CancellationToken ct);
```
Resolves `PartyId` → `Investor.KycStatus = Approved`. Used by Transaction module KYC gate.

---

#### Why Path 2 Converges to the ChatGPT Model

This is identical to ChatGPT's `Party + PartyRole` pattern:
- `Party` = universal legal identity (Individual, Company, Trust…) — **you always create a Party first**
- `Investor` = KYC/compliance role profile carried by that Party — a strongly-typed role entity
- `FundManagerProfile`, `DistributorProfile` etc. will follow the same pattern (PartyId FK, 1:0-1)
- `PartyLegalStructure` = "what you are"; `PartyFunctionalRole` = "what you do" — these are orthogonal

An Individual investor: `Party(LegalStructure=Individual, FunctionalRole=null)` + `Investor(PartyId=…, LegalStructure=Individual)`.

A Fund Manager firm: `Party(LegalStructure=Company, FunctionalRole=FundManager)` + *(future)* `FundManagerProfile(PartyId=…)`.

---

#### Migration Strategy

Since this is a feature branch with no production data, the migration can be data-aware but non-destructive:

```sql
-- 1. Add LegalStructure column to crm.Parties
ALTER TABLE crm.Parties ADD LegalStructure tinyint NULL;

-- 2. Back-fill LegalStructure from PartyType (all current Parties are corporate service providers)
UPDATE crm.Parties SET LegalStructure = 2  -- Company
  WHERE PartyType IN (1,2,3,4,5,6,7);      -- all existing PartyType values → Company

-- 3. Make LegalStructure NOT NULL; drop old PartyType column (no FunctionalRole column added)
ALTER TABLE crm.Parties ALTER COLUMN LegalStructure tinyint NOT NULL;
ALTER TABLE crm.Parties DROP COLUMN PartyType;

-- 4. Create PartyRoleAssignments table
CREATE TABLE crm.PartyRoleAssignments (
  Id uniqueidentifier NOT NULL DEFAULT NEWSEQUENTIALID() PRIMARY KEY,
  TenantId uniqueidentifier NOT NULL,
  PartyId uniqueidentifier NOT NULL REFERENCES crm.Parties(Id) ON DELETE CASCADE,
  Role tinyint NOT NULL,
  AssignedAt datetimeoffset NOT NULL,
  AssignedBy uniqueidentifier NOT NULL,
  CreatedAt datetimeoffset NOT NULL,
  UpdatedAt datetimeoffset NOT NULL,
  CreatedBy uniqueidentifier NULL,
  UpdatedBy uniqueidentifier NULL
);
CREATE UNIQUE INDEX UQ_PartyRoleAssignments_TenantPartyRole
  ON crm.PartyRoleAssignments(TenantId, PartyId, Role);

-- 5. Seed existing PartyType values into PartyRoleAssignments
-- (maps old PartyType int → new PartyFunctionalRole int; Other=5 → no role)
INSERT INTO crm.PartyRoleAssignments (Id, TenantId, PartyId, Role, AssignedAt, AssignedBy, CreatedAt, UpdatedAt)
SELECT NEWSEQUENTIALID(), TenantId, Id,
       CASE PartyType_old  -- stored temporarily before drop; or done in EF migration C# code
         WHEN 1 THEN 1  -- FundManager
         WHEN 2 THEN 2  -- Distributor
         WHEN 3 THEN 3  -- Custodian
         WHEN 4 THEN 4  -- TransferAgent
         WHEN 6 THEN 5  -- AdvisoryFirm
         WHEN 7 THEN 6  -- AdvisoryBranch
       END,
       GETUTCDATE(), '00000000-0000-0000-0000-000000000000', GETUTCDATE(), GETUTCDATE()
FROM crm.Parties WHERE PartyType_old NOT IN (5);  -- skip Other → no role

-- 6. Add PartyId FK to crm.Investors
ALTER TABLE crm.Investors ADD PartyId uniqueidentifier NULL;
ALTER TABLE crm.Investors ADD CONSTRAINT FK_Investors_Party
  FOREIGN KEY (PartyId) REFERENCES crm.Parties(Id);
CREATE UNIQUE INDEX UQ_Investors_TenantParty
  ON crm.Investors(TenantId, PartyId) WHERE PartyId IS NOT NULL;
```

> **Implementation note:** In EF Core C# migration code, retain the old `PartyType` column value temporarily before dropping it; use it to seed `PartyRoleAssignments`. This is simpler than the raw SQL above and avoids the temporary alias.

---

#### Impact on Other Entities

- **`PartyInvestmentAccountLink`**: No change to schema — `PartyId` FK already points to `crm.Parties`. After Path 2, individual investors will have a `Party` record, so `PartyInvestmentAccountLink` naturally covers all account holder types.
- **`AdvisorInvestmentAccountLink`**: No change.
- **`PartyRelationship`**: No change — already Party-to-Party.
- **`CreatePartyCommand`**: Require `PartyLegalStructure`; accept optional `PartyFunctionalRole`. Remove `PartyType` from request DTO.
- **`GetPartiesQuery` / `GetPartyByIdQuery`**: Replace `PartyType` filter/field with `LegalStructure` + `FunctionalRole`.

---

#### Why Not Path 1 or Path 3

- **Path 1** (dual nullable FKs on `AccountHolderLink`): Leaves two identity systems alive with no bridge. Every downstream consumer must handle both.
- **Path 3** (full merge): Too disruptive — `Party` and `Investor` have different lifecycles, KYC/AML is investor-domain concern, not party-domain.

See `/docs/crm/taurus_inv_schema_analysis.md` Section 8 for full prior analysis.

---

### Q5 — Advisor Rep Identity: Party record + UserPartyLink ✅ DECIDED: Option A

**Decision:** Individual advisor reps get a `Party(Individual, AdvisorRep)` record. A `UserPartyLink` table in CRM bridges `UserId` (auth) → `PartyId` (CRM). `ICurrentUser.PartyId` reads the `party_id` JWT claim.

---

#### The Problem

The `AdvisoryAuthorizationTemplate` requires an `advisorPartyId` to evaluate authorization. When an advisor rep logs in, they are a `User` in the auth module — not a `Party` in CRM. Without a bridge, `advisorPartyId` cannot be resolved at runtime.

Additionally, individual human advisor reps (the people who log in and place trades) had no entity in the model — only `AdvisoryFirm` and `AdvisoryBranch` were defined.

---

#### Option A Design

**New `PartyFunctionalRole` enum value:**
`AdvisorRep = 7` — individual human advisor rep; always paired with `LegalStructure = Individual`; stored via `PartyRoleAssignment`, not as a column on `Party`

**Workflow for onboarding an advisor rep:**
1. Admin creates `Party(LegalStructure=Individual)` then calls `AssignPartyRoleCommand(partyId, AdvisorRep)`
2. Admin creates `PartyRelationship(ParentFirm)` from rep's Party → their AdvisoryBranch (or AdvisoryFirm directly)
3. Admin calls `LinkUserToPartyCommand(userId, partyId)` — creates `UserPartyLink` + updates `party_id` claim on the User via `IIdentityProvider.UpdateUserClaimsAsync`
4. On next login, JWT contains `party_id` claim
5. `ICurrentUser.PartyId` reads the claim — available to all ABAC templates with zero DB lookups per request

**`UserPartyLink` entity:**
```csharp
public class UserPartyLink : BaseEntity
{
    public Guid UserId { get; private set; }     // value ref — no FK to auth schema
    public Guid PartyId { get; private set; }    // FK → crm.Parties
    public Guid TenantId { get; private set; }
}
```
Indexes: `UNIQUE(TenantId, UserId)` — one portal identity per user per tenant. No `UNIQUE(TenantId, PartyId)` — multiple users may link to the same corporate Party.

**`ICurrentUser` extension:**
```csharp
Guid? PartyId { get; }   // reads "party_id" claim; null if user has no CRM Party link
```

**`AdvisoryAuthorizationTemplate` updated flow:**
```csharp
var advisorPartyId = _currentUser.PartyId
    ?? throw new InvalidOperationException("Caller has no linked Party.");
return await reader.HasAdvisoryAuthorizationAsync(
    advisorPartyId, attrs.InvestorPartyId, attrs.TenantId, ct);
```

---

#### Portal Generalisation (Future)

This pattern extends identically to investor portal users:

| Portal | User links to | Party type | Profile |
|---|---|---|---|
| AdvisorPortal | `UserPartyLink` → `Party(Individual, AdvisorRep)` | Advisor rep | — |
| InvestorPortal | `UserPartyLink` → `Party(Individual, null)` | Individual investor | `Investor(PartyId=...)` |

When an investor self-registers on InvestorPortal:
1. Auto-provision creates `Party(Individual, null)` + `Investor(PartyId=...)` + `UserPartyLink`
2. JWT gets `party_id` claim
3. `ICurrentUser.PartyId` resolves KYC profile, holdings, and accounts

---

#### Why Option A over Option B

Option B (firm-level only, `party_id` claim set manually) loses individual rep tracking — no audit of which specific person took an action, no per-rep authorization scope. Option A gives full traceability and naturally extends to investor self-service portals, which is a stated future goal.

---

## Decision Summary

| Q | Decision | Impact |
|---|---|---|
| Q1 — LinkOrder uniqueness | ✅ Option B — application-layer validation; `LinkPartyToInvestmentAccountCommandValidator` enforces uniqueness, single-holder rule, ownership % cap | Phase 2 — validator |
| Q2 — ABAC traversal | ✅ Option A — C# `AdvisoryAuthorizationTemplate`; depth-capped hierarchy traversal; per-request cache | Phase 1 (template) + Phase 2 (registration) |
| Q3 — Data migration | ✅ Clean drop — confirm zero rows pre-migration; update affected tests in Phase 6 | Phase 3 — migration |
| Q4 — Investor ↔ Party FK | ✅ Path 2 — add `PartyId` FK to `Investor`; retire `PartyType` → `PartyLegalStructure` (required, single) + `PartyRoleAssignment` table (multi-role); UNIQUE(TenantId, PartyId) filtered index on `Investors`; add `IsPartyKycApprovedAsync` to `ICrmReader` | Phase 1 (entities + enums) + Phase 3 (migration) + Phase 5 (ICrmReader) |
| Q5 — Advisor/Investor User identity bridge | ✅ Option A — `AdvisorRep=7` in `PartyFunctionalRole`; `UserPartyLink` table (`UserId` value ref + `PartyId` FK); `party_id` JWT claim; `ICurrentUser.PartyId`; generalises to InvestorPortal | Phase 1 (entity) + Phase 2 (commands) + Phase 3 (EF) + Phase 4 (endpoints) |
| Q6 — Holdings/Transaction FK | ✅ `InvestmentAccountId` replaces `InvestorId` (+ remove `PartyId` from Transaction) — holdings and trades belong to an account, not directly to an investor; joint/trust/multi-account scenarios all require account-level granularity | Phase 1 (domain) + Phase 2 (app) + Phase 3 (infra) + Phase 4 (presentation) + Phase 5 (abstractions) |

---

## Status History

| Date | Status | Notes |
|---|---|---|
| 2026-04-13 | Plan | Plan created — based on Taurus inv schema analysis + ChatGPT CRM design discussion |
| 2026-04-13 | Plan | Open questions expanded with detailed analysis and recommendations |
| 2026-04-13 | Plan | Q1 → Option B, Q2 → Option A, Q3 → clean drop confirmed; Q4 deferred for separate discussion. Implementation steps updated accordingly |
| 2026-04-13 | Plan | Legal-structure profile design finalised: Investor base + extension tables (IndividualInvestorProfile, CorporateInvestorProfile, TrustInvestorProfile) using explicit composition pattern (not EF inheritance). PartyLegalStructure enum replaces InvestorType. Phase 1/3 implementation steps updated. |
| 2026-04-13 | Plan | Q4 → Path 2: add PartyId FK to Investor; split PartyType → PartyLegalStructure (required) + PartyFunctionalRole (nullable) on Party; UNIQUE(TenantId,PartyId) filtered index; IsPartyKycApprovedAsync on ICrmReader. Decision Summary, Phase 1/3/5 steps updated. |
| 2026-04-13 | Plan | Naming consistency: AccountType → InvestmentAccountType, AccountRelationshipType → InvestmentAccountRelationshipType, PartyAccountLink → PartyInvestmentAccountLink, AdvisorAccountLink → AdvisorInvestmentAccountLink. |
| 2026-04-13 | Plan | Review pass: removed stale PartyType expansion section; updated Layers Touched; added Id + audit fields to PartyInvestmentAccountLink; fixed ISO alpha-2/3 inconsistency on InvestorDocument; renamed Link*ToAccount commands to Link*ToInvestmentAccount; fixed ABAC seed resource name; added CreateInvestorCommand profile step; updated integration test scenario for Path 2 workflow. |
| 2026-04-13 | Plan | Q5 → Option A: AdvisorRep=7 in PartyFunctionalRole; UserPartyLink entity (UserId value ref + PartyId FK); party_id JWT claim; ICurrentUser.PartyId. Generalises to InvestorPortal. Goals, Layers Touched, entity definitions, Phase 1/2/3/4 steps, Decision Summary updated. |
| 2026-04-13 | Plan | Q6 → Holding.InvestorId and Transaction.InvestorId migrate to InvestmentAccountId; Transaction.PartyId removed. Holdings/Transaction entity definitions, ICrmReader (IsInvestmentAccountKycApprovedAsync), IHoldingsReader, all affected phases and tests updated. |
| 2026-04-13 | Plan | Architecture review (ChatGPT): accepted 3 of 7 recommendations. (1) UserPartyLink — removed `UNIQUE(TenantId, PartyId)`; many Users may link to same corporate Party; only `UNIQUE(TenantId, UserId)` retained. (2) PartyRelationship direction semantics — added XML doc convention per enum value + direction guard in `CreatePartyRelationshipCommandValidator`. (3) Holdings uniqueness — added `UNIQUE(TenantId, InvestmentAccountId, ClassId)` to prevent duplicate position rows. Deferred: Investor decomposition (Phase 3), AccessGrant model (future), ledger separation (Phase 3). |
| 2026-04-13 | Plan | Multi-role fix: replace `Party.PartyFunctionalRole` (single nullable enum) with `PartyRoleAssignment` junction table. A Party can now hold multiple simultaneous functional roles (e.g. Investor + AdvisorRep + Trustee). `Trustee=8` added to `PartyFunctionalRole` enum. `PartySummaryDto.Roles` is now a list. All phases, Q4 migration SQL, Q5 workflow, integration tests, and Decision Summary updated. Rationale: ChatGPT design's "decouple identity from behaviour" principle; single enum cannot represent multi-role Parties. |
