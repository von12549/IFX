# Taurus `inv` Schema Analysis & IFX Design Decisions
> **Source:** SQL Server `DESKTOP-OVPKDKR`, database `taurus`, schema `inv`
> **Created:** 2026-04-12 | **Updated:** 2026-04-13
> **Purpose:** Reverse-engineer the legacy CRM design and record confirmed IFX design decisions
> **Related:** `/docs/crm/crm_design_summary.txt`, `/docs/crm/crm_advisor_design_discussion.md`

---

## 1. Schema Overview

The `inv` schema contains **173 objects** (tables, views, trackers) grouped by prefix convention:

| Prefix | Meaning | Count (approx) |
|---|---|---|
| `tbl_S_` | Static / entity master tables | ~70 |
| `tbl_L_` | Link / relationship tables | ~20 |
| `tbl_D_` | Document / event tables | ~2 |
| `tbl_T_` | Tracker / temp staging tables | ~4 |
| `tbl_S_*_Audit` | Audit shadow tables (one per entity) | ~60 |
| `vw_` | Views | ~8 |

**Column naming convention:**
| Prefix | Type |
|---|---|
| `k` | Integer key (PK or FK) |
| `v` | varchar / string |
| `dt2` | datetime2 |
| `d` | date |
| `b` | bit (boolean) |
| `dec` | decimal |
| `i` | int (non-key) |
| `z` | system (e.g. `zVersion` = rowversion) |

---

## 2. Core Entity Map

### 2.1 INVInvestorNames — The Legal Entity (≈ IFX `Party`)

**Table:** `tbl_S_INVInvestorNames`

| Column | Type | Notes |
|---|---|---|
| `kINVInvestorNames` | int PK | Investor master key |
| `vINVNumber` | varchar(50) | Investor number (= PartyCode equivalent) |
| `vINVSalutation` | varchar(20) | For individuals |
| `vINVFirstName` | varchar(60) | |
| `vINVMiddleName` | varchar(60) | |
| `vINVSurname` | varchar(130) | |
| `vINVBusinessName` | varchar(100) | For corporate entities |
| `vINVAlsoKnownAs` | varchar(100) | AKA / trading name |
| `kINVInvestorEntityType` | int FK | Individual, Company, Trust, Partnership, etc. (14 types) |
| `kINVInvestorEntitySubType` | int FK | Sub-classification |
| `kCountry` | int FK | Incorporation/registration country |
| `bIsPublic` | bit | Publicly listed entity |
| `vRegulator` | varchar(255) | Regulator name |
| `vLicenseNo` | varchar(60) | |
| `vGIIN` | varchar(60) | FATCA Global Intermediary ID Number |
| `kFATCACRSStatus` | int FK | FATCA/CRS classification |
| `vOtherFATCAStatus` | varchar(255) | Free-text FATCA detail |
| `kTaxResidenceOrgType` | int FK | |

**Entity Types (actual data):** Individual, Company, Government Entity, Joint Holding, Incorporated Assoc, Unincorporated Assoc, Superannuation Fund, Trust, Partnership, Charitable Trust, and more.

> **Key insight:** `INVInvestorNames` is the legal entity (person or organisation). It maps to what IFX calls `Party`, not `Investor`. The word "Investor" in the legacy system covers both the legal entity and its investment behaviour.

---

### 2.2 INVAccount — The Investment Account ✅ CONFIRMED: IFX needs `InvestmentAccount`

**Table:** `tbl_S_INVAccount`

| Column | Type | Notes |
|---|---|---|
| `kINVAccount` | int PK | Account key |
| `vINVACCountNumber` | varchar(50) | Account number (unique reference) |
| `kINVInvestorEntityType` | int FK | Type of account (Individual, Trust, etc.) |
| `kINVAccountStatus` | int FK | Active / Inactive / Locked |
| `kINVAccountClassification` | int FK | Classification code |
| `dCertificateDate` | date | Certificate issuance date |
| `isblocked` | int | Block flag |

> **Decision (2026-04-13):** IFX **will introduce an `InvestmentAccount` entity** in the CRM module. It sits between `Party` (legal entity) and the unit holding records in the `Holdings` module.
>
> The correct entity mapping is:
> - Legacy `INVInvestorNames` → IFX `Party` (legal entity)
> - Legacy `INVAccount` → IFX `InvestmentAccount` (in CRM, owned by one or more Parties)
> - Holdings unit balance records → IFX `Holdings` module (linked to `InvestmentAccount`)
>
> **IFX `InvestmentAccount` proposed fields:**
> - `AccountNumber` (unique per tenant)
> - `AccountType` (Individual, Joint, Trust, Corporate, SuperannuationFund, etc.)
> - `Status` (Active, Inactive, Locked)
> - `TenantId`
> - `CertificateDate` (optional)
> - Audit fields

---

### 2.3 AdvisoryGroup — Advisor Firm (≈ IFX `Party` with type=AdvisoryFirm)

**Table:** `tbl_S_AdvisoryGroup`

| Column | Type | Notes |
|---|---|---|
| `kAdvisoryGroup` | int PK | |
| `vAdvisoryGroupName` | varchar(60) | Firm name |
| `vLicenceNumber` | varchar(16) | AFSL / licence number |
| `bIsActive` | bit | |
| `bIsNoClientEmails` | bit | Suppress client email communications |

---

### 2.4 AdvisoryBranch — Branch Office (≈ IFX `Party` with type=AdvisoryBranch)

**Table:** `tbl_S_AdvisoryBranch`

| Column | Type | Notes |
|---|---|---|
| `kAdvisoryBranch` | int PK | |
| `vAdvisoryBranchName` | varchar(40) | Branch name |
| `kAdvisoryGroup` | int FK | Parent firm |
| `dDateFrom` / `dDateTo` | date | Branch effective period |
| `bIsActive` | bit | |

---

### 2.5 AdvisorNames — Individual Advisor / Rep (→ IFX `User` with Advisor role, NOT a Party)

**Table:** `tbl_S_AdvisorNames`

| Column | Type | Notes |
|---|---|---|
| `kAdvisorNames` | int PK | |
| `vADVSalutation` | varchar(20) | |
| `vADVFirstName` / `vADVMiddleName` / `vADVSurname` | varchar | Personal name |
| `vLicenceRepNo` | varchar(20) | Individual rep licence number |
| `vADVInternalNumber` | varchar(50) | Internal staff number |

> Individual advisors are **people**, not legal entities. They belong to a Branch which belongs to a Group.
> In IFX: modelled as `User` with an Advisor role, with an optional `PartyId` field linking them to their employer `Party` (AdvisoryGroup or AdvisoryBranch).

---

### 2.6 AdvisorySupportStaff — Branch Support Staff (→ IFX `User`)

**Table:** `tbl_S_AdvisorySupportStaff`

| Column | Type | Notes |
|---|---|---|
| `kSupportStaff` | int PK | |
| Name fields | varchar | First/Middle/Surname |
| `kAdvisoryGroup` | int FK | |
| `kAdvisoryBranch` | int FK | |
| `vSSEmail` | varchar(200) | |
| `vSupportStaffNumber` | varchar(50) | |

---

## 3. Relationship Map

### 3.1 Investor ↔ Account Link (→ IFX `PartyAccountLink`)

**Table:** `tbl_L_INVInvestorAccountLink`

| Column | Notes |
|---|---|
| `kINVAccount` | FK → Account |
| `kinvInvestorNames` | FK → Investor |
| `kINVInvestorACCRelshpType` | Relationship type (see below) |
| `iINVInvestorLinkOrder` | Order of investors on account (for joint holdings) |
| `decOwnershipPercentage` | % ownership |
| `decOwnershipNominatedUnits` | Units nominated |
| `iINVAccountLinked` | Linked account flag |

**Relationship Types (actual data):**
| ID | Name | Description |
|---|---|---|
| 1 | Registered Holder | The legal person(s) in whose name the holding is registered |
| 2 | Beneficial Holder | Entity on whose behalf the holding is registered |
| 3 | Trust Beneficiary | Beneficiary of a trust or controlling shareholder |
| 4 | Controlling Entity | Entity that controls another (e.g. ultimate holding company) |
| 5 | Agent | Person appointed to act on behalf of another (limited powers) |

> No effective dates on this link — the relationship is considered permanent (changes tracked via audit table).
> **IFX decision:** `decOwnershipPercentage` will be carried on the `PartyAccountLink` relationship.

---

### 3.2 Advisor ↔ Account Link (→ IFX `AdvisorAccountLink`)

**Table:** `tbl_L_AdvisorAccountLink`

| Column | Notes |
|---|---|
| `kAdvisorNames` | FK → Individual Advisor |
| `kINVAccount` | FK → Account |
| `dADVAccDateFrom` / `dADVAccDateTo` | Effective period — advisor can be transferred |
| `decRebateRate` | Commission rebate rate stored **on the relationship** |

> **Decision (2026-04-13):** Advisor links to **InvestmentAccount**, not to Investor/Party directly.
> This makes business sense — the advisor manages the investment, not the person. A person can have multiple accounts with different advisors.
>
> **IFX `AdvisorAccountLink` fields:** `AdvisorPartyId`, `InvestmentAccountId`, `TenantId`, `EffectiveDate`, `ExpiryDate`, `RebateRate` (decimal).
>
> See Section 7.2 for how authorization handles the "which investors can this advisor serve" question.

---

### 3.3 Investor ↔ Investor Link — Party-to-Party ✅ CONFIRMED needed

**Table:** `tbl_L_INVInvestorInvestorLink`

| Column | Notes |
|---|---|
| `kINVInvestornames` | FK → child investor |
| `iParentInvestor` | FK → parent investor |
| `kINVInvestorACCRelshpType` | Same relationship type lookup |

> This is the equivalent of **Party-to-Party** relationships in the ChatGPT design. Used to model:
> - Company → Director (Beneficial Owner)
> - Trust → Trustee (Registered Holder)
> - Company → Ultimate Holding Company (Controlling Entity)
>
> **Decision (2026-04-13):** IFX will introduce `PartyRelationship(FromPartyId, ToPartyId, RelationshipType, TenantId, EffectiveDate, ExpiryDate)` table.
> This is separate from `PartyInvestorRelationship` (which will be retired or repurposed once `InvestmentAccount` is in place).

---

### 3.4 Advisor Hierarchy Links ✅ CONFIRMED: Group and Branch are Parties

**AdvisorToGroupLink:** `tbl_L_AdvisorToGroupLink`
- `kAdvisorNames` → `kAdvisoryBranch` → `kAdvisoryGroup`
- An individual advisor belongs to a branch, which belongs to a group (firm)

**ADVBDM_AdvisorLink:** `tbl_L_ADVBDM_AdvisorLink`
- `kAdvisorNames` ↔ `kADVBDMUser`
- BDM (Business Development Manager) assigned to manage an advisor

**AdvisorSupportStaffLink:** `tbl_L_AdvisorSupportStaffLink`
- `kSupportStaff` ↔ `kAdvisorNames`
- Support staff assigned to assist a specific advisor

> **Decision (2026-04-13):**
> - `AdvisoryGroup` → IFX `Party` with `PartyType = AdvisoryFirm`
> - `AdvisoryBranch` → IFX `Party` with `PartyType = AdvisoryBranch`
> - `AdvisoryGroup → AdvisoryBranch` → IFX `PartyRelationship(type = ParentFirm)`
> - `AdvisorNames` (individual rep) → IFX `User` (not a Party)

---

## 4. Compliance / Regulatory Data

### 4.1 Legacy AML/KYC Tables (Taurus)

| Table | Key Fields |
|---|---|
| `tbl_S_INVInvestorAMLStatus` | `vAMLGatewayReference`, `kAMLIDStatus`, `kAMLGateway`, `kAMLSimplifiedProcedureTypes` |
| `tbl_S_INVAMLPEP` | `vPEPDetails`, `vSourceOfWealth` (linked to Investor) |
| `tbl_S_INVNationalityResidence` | `iNationality`, `bIsCitizen`, `bPEPStatus`, `bIsTaxResident`, `vTIN`, `kFATCACRSStatus` |
| `tbl_S_INVPersonalDetails` | `dDateOfBirth`, `kINVSex`, `dDateOfDeath` |
| `tbl_S_INVBusinessRegistrationNumber` | Business reg numbers |
| `tbl_S_INVBusinessTaxNumber` | Business tax numbers |
| `tbl_S_INVPersonalTaxNumber` | Personal TFN/TIN |

### 4.2 FrankieOne KYC/AML Entity Model

FrankieOne (frankieone.com) is an identity verification and AML platform that provides a unified entity model for individuals and organisations.

**Individual Identity Fields:**

| Field | Notes |
|---|---|
| `givenName` / `familyName` / `middleName` | Full name |
| `dateOfBirth` (year, month, day) | Structured DOB |
| `gender` | M / F / U (Unspecified) / O (Other) |
| `home_country_givenname` / `home_country_familyname` | Native script names for non-Latin countries |
| `addresses[]` | Multiple addresses: residential, postal (country, state, town, streetName, streetNumber, unitNumber, postalCode, addressType) |
| `documents[]` | documentType, documentNumber, issueCountry, issueState, expiryDate, issueDate |
| `email`, `mobile` | Contact |

**Organisation/Business Fields:**

| Field | Notes |
|---|---|
| `entityType` | INDIVIDUAL / ORGANISATION / TRUST |
| `organizationData.registeredName` | Legal registered name |
| ABN / ACN via `extraData[kvpType="id.external"]` | Australian business identifiers |
| `addresses[]` | Same structure as individuals |
| UBO (Ultimate Beneficial Owner) | Linked individual entities |

**AML Screening Results:**

| Field | Notes |
|---|---|
| `numUnresolvedPEP` | Count of unresolved PEP matches |
| `numUnresolvedSanction` | Count of unresolved sanctions matches |
| `numUnresolvedAdverseMedia` | Count of unresolved adverse media alerts |
| `processResults[]` | Array of AML match objects (name, year of birth, country) |
| `supplementaryData` | Matched entity details |
| `mediaData[]` | Adverse media match details |
| `manualStatus` | Compliance team override (e.g. FALSE_POSITIVE) |

**Profile Status Values:** `VERIFIED`, `PENDING`, `RESULTS_RETRIEVED`, `RESULTS_ERROR`

**KYC Check Types:** Document verification, biometrics (liveness + face match), watchlist (PEP/sanctions), blocklist, data source (electoral roll, credit bureau), duplicate, government ID, fraud.

### 4.3 ✅ DECISION: IFX `Investor` KYC/AML Enrichment

Current IFX `Investor` has only `KycStatus` enum + `KycReviewedAt`. The following fields will be added, drawing from both Taurus and FrankieOne models:

**Personal (Individual investors):**
| IFX Field | Source | Notes |
|---|---|---|
| `DateOfBirth` | Taurus + FrankieOne | Required for identity verification |
| `DateOfDeath` | Taurus | Lifecycle management |
| `Gender` | FrankieOne | M/F/U/O |
| `PlaceOfBirth` | FrankieOne | Country/city |

**Nationality & Tax Residency:**
| IFX Field | Source | Notes |
|---|---|---|
| `NationalityCountry` | Taurus | ISO country code |
| `IsCitizen` | Taurus | Boolean |
| `TaxResidencyCountry` | Taurus + FrankieOne | Primary tax residence |
| `TIN` | Taurus + FrankieOne | Tax Identification Number |
| `FatcaCrsStatus` | Taurus | Enum: NotReviewed, Compliant, Exempt, ReportingRequired |
| `GIIN` | Taurus | FATCA Global Intermediary ID (for financial institutions) |
| `IsPEP` | Taurus + FrankieOne | Politically Exposed Person flag |

**AML / Identity Verification (linked to FrankieOne):**
| IFX Field | Source | Notes |
|---|---|---|
| `AmlStatus` | Taurus + FrankieOne | Enum: NotChecked, Clear, Review, Blocked |
| `AmlGatewayReference` | Taurus + FrankieOne | External provider reference (FrankieOne `entityId`) |
| `AmlCheckedAt` | FrankieOne | Last AML check timestamp |
| `PepDetails` | Taurus | Free text PEP context |
| `SourceOfWealth` | Taurus | Free text or structured |
| `UnresolvedPepCount` | FrankieOne | `numUnresolvedPEP` |
| `UnresolvedSanctionCount` | FrankieOne | `numUnresolvedSanction` |
| `UnresolvedAdverseMediaCount` | FrankieOne | `numUnresolvedAdverseMedia` |

**Business / Corporate investors:**
| IFX Field | Source | Notes |
|---|---|---|
| `BusinessRegistrationNumber` | Taurus | ABN/ACN equivalent |
| `BusinessTaxNumber` | Taurus | |
| `IsPubliclyListed` | Taurus | |
| `Regulator` | Taurus | Regulatory body name |
| `LicenseNumber` | Taurus | |

> **Note on KYC document storage:** Identity documents (passport, driver's licence) will be stored in a separate `InvestorDocument` child table (documentType, documentNumber, issueCountry, issueState, expiryDate) rather than embedded in `Investor`. This mirrors the FrankieOne `documents[]` array pattern and supports multiple documents per investor.

> **FrankieOne integration approach:** Rather than duplicating all AML check data in IFX, store the `AmlGatewayReference` (FrankieOne `entityId`) as the pointer to the authoritative source. IFX stores the summary result (status, counts, timestamp) for quick policy evaluation. Full check history lives in FrankieOne.

---

## 5. The Advisor Model (Legacy vs IFX Revised)

### 5.1 Legacy Three-Tier Model

```
AdvisoryGroup (Firm / AFSL holder)
  └── AdvisoryBranch (Regional office / sub-entity)
        └── AdvisorNames (Individual licensed rep)
              └── AdvisorySupportStaff (Admin staff supporting the advisor)
              └── BDM (Business Dev Manager assigned to this advisor)
```

The advisor links to **Accounts** (not investors directly):
```
AdvisorNames ──[AdvisorAccountLink]──► INVAccount
                  └── dDateFrom / dDateTo
                  └── decRebateRate
```

### 5.2 IFX Revised Model (as of 2026-04-13)

```
Party(AdvisoryFirm) ──[PartyRelationship: ParentFirm]──► Party(AdvisoryBranch)
                                                              │
                                            User(Advisor Rep, linked to Branch Party)
                                                              │
                                        [AdvisorAccountLink: DateFrom/DateTo/RebateRate]
                                                              │
                                                   InvestmentAccount
                                                              │
                                     [PartyAccountLink: RegisteredHolder/BeneficialHolder/...]
                                                              │
                                                           Party (Investor)
```

---

## 6. Advisor Access Policy — How Advisors Authorise Investment Creation

> **Question:** If Advisor links to `InvestmentAccount` only, how should access policies be set up for advisors? For example: which Investor the advisor could help to create an investment for?

**The problem:** When creating a *new* `InvestmentAccount`, no account exists yet — so the advisor cannot be validated via an `AdvisorAccountLink`. A different authorization mechanism is needed for the pre-account phase.

**Solution: Two-layer advisor authorization model**

#### Layer 1 — Client Engagement (Party-to-Party, pre-account)

Introduce a `PartyRelationship` of type `AuthorizedToAdvise` between the Advisor's Party and the Investor's Party:

```
Party(AdvisoryFirm or Branch) ──[PartyRelationship: AuthorizedToAdvise]──► Party(Investor)
  └── EffectiveDate / ExpiryDate
  └── TenantId
```

This is the **engagement contract**: the advisor firm is permitted to act on behalf of this investor. It is created when the investor formally engages the advisor (signs a fee disclosure statement, etc.).

**ABAC policy for creating an InvestmentAccount:**
```
ALLOW IF:
  currentUser.AdvisorPartyId has PartyRelationship(
    type = AuthorizedToAdvise,
    ToPartyId = command.InvestorPartyId,
    isActive = true
  )
```

#### Layer 2 — Account Service (AdvisorAccountLink, post-account)

Once the account is created, the `AdvisorAccountLink` is established. This governs ongoing access to that specific account:

```
ALLOW IF:
  currentUser.AdvisorPartyId has AdvisorAccountLink(
    InvestmentAccountId = target.AccountId,
    isActive = true
  )
```

#### Summary: What each relationship type controls

| Relationship | Controls | When created |
|---|---|---|
| `PartyRelationship(AuthorizedToAdvise)` | Can create investment for this investor; can view investor's profile | When advisor engagement begins |
| `AdvisorAccountLink` | Can manage/view this specific investment account; earns rebate on this account | When account is opened |
| `PartyRelationship(ParentFirm)` | Firm hierarchy; branch inherits firm-level authorizations | When branch is set up |

#### Inheritance consideration

An advisor's authorization should be resolvable through their firm hierarchy:
- If `User(Advisor Rep)` → `Party(AdvisoryBranch)` → `Party(AdvisoryFirm)` has `AuthorizedToAdvise` for Investor X, the individual rep inherits that authorization.
- ABAC policy checks the rep's `PartyId` chain, not just the direct link.
- This can be implemented as an OPA condition template: `HasAdvisoryAuthorization(advisorPartyId, investorPartyId)` that traverses the hierarchy.

---

## 7. Key Structural Differences vs IFX CRM (Updated)

| Aspect | Legacy `taurus.inv` | IFX CRM (revised decision) | Status |
|---|---|---|---|
| Legal entity | `INVInvestorNames` | `Party` | ✅ Equivalent |
| Investment account | `INVAccount` (separate entity) | `InvestmentAccount` (new entity in CRM) | ✅ Decision made |
| Investor type taxonomy | 14 entity types + sub-types | Expand `InvestorType` + `EntitySubType` | 🔲 To implement |
| Advisor firm/branch | Separate entities | `Party(AdvisoryFirm)` + `Party(AdvisoryBranch)` | ✅ Decision made |
| Individual advisor | `AdvisorNames` (person) | `User` with Advisor role + linked to Party | ✅ Decision made |
| Advisor hierarchy | AdvisoryGroup → Branch | `PartyRelationship(ParentFirm)` | ✅ Decision made |
| Advisor–account link | Advisor → Account | `AdvisorAccountLink` (Advisor Party → InvestmentAccount) | ✅ Decision made |
| Advisor–investor auth | Implicit (via account) | `PartyRelationship(AuthorizedToAdvise)` | ✅ Decision made |
| Commission on relationship | `decRebateRate` on AdvisorAccountLink | `RebateRate` on `AdvisorAccountLink` | ✅ Store on relationship |
| Party-to-Party | `INVInvestorInvestorLink` | `PartyRelationship` table | ✅ Decision made |
| Ownership % | `decOwnershipPercentage` on Investor-Account link | On `PartyAccountLink` | ✅ Decision made |
| AML/KYC depth | Gateway ref, PEP, Source of Wealth, TIN, FATCA | Enriched fields + FrankieOne reference | ✅ Decision made |
| Identity documents | Separate table per doc type | `InvestorDocument` child table | ✅ Decision made |
| Name versioning | Name in separate table | Name embedded (no versioning for now) | 🔲 Future |
| Multi-tenant | Not present (single tenant) | Full TenantId isolation | ✅ IFX ahead |
| Audit trail | `_Audit` shadow tables | `IAuditableEntity` (CreatedBy/At, UpdatedBy/At) | ✅ Adequate for now |

---

## 8. Design Decisions Summary

| # | Question | Decision |
|---|---|---|
| 1 | Does IFX need an explicit `InvestmentAccount` entity? | **Yes.** Add to CRM module. Sits between Party and Holdings. |
| 2 | How to authorize advisors without a pre-existing account? | **Two-layer model:** `PartyRelationship(AuthorizedToAdvise)` for creation authorization; `AdvisorAccountLink` for ongoing account access. OPA template `HasAdvisoryAuthorization` traverses firm hierarchy. |
| 3 | Should AdvisoryGroup and AdvisoryBranch become Parties? | **Yes.** `PartyType` gains `AdvisoryFirm` and `AdvisoryBranch`. Connected via `PartyRelationship(ParentFirm)`. Individual reps remain Users. |
| 4 | Is Party-to-Party needed? | **Yes.** `PartyRelationship(FromPartyId, ToPartyId, RelationshipType, TenantId, EffectiveDate, ExpiryDate)` table. Covers advisor hierarchy AND corporate investor structures (BeneficialOwner, ControllingEntity, TrustBeneficiary). |
| 5 | How much KYC/AML detail? | **Enrich based on Taurus + FrankieOne** (see Section 4.3). Store `AmlGatewayReference` pointing to FrankieOne entity. Add `InvestorDocument` child table. FATCA/CRS, PEP, TIN, AML status all required. |
| 6 | Commission/rebate rate: CRM field or separate module? | **Store `RebateRate` on `AdvisorAccountLink` for now.** See Section 9 for future Commission module path. |

---

## 9. Future: Commission Module (Deferred)

The `RebateRate` stored on `AdvisorAccountLink` covers the simple case (a single trail commission rate per advisor-account relationship). A dedicated Commission module would be needed if any of the following requirements arise:

- **Tiered rebate rates** — different rates based on AUM thresholds
- **Split commissions** — fee shared between firm and rep, or between two advisors
- **Commission accrual and payment tracking** — scheduled payments, payment history
- **Fee type variety** — upfront fees, trail fees, platform fees, adviser service fees
- **Commission statements** — periodic statements sent to advisors

**Proposed Commission module scope (when needed):**

```
CommissionAgreement
  ├── AdvisorPartyId
  ├── InvestmentAccountId (or FundClassId for product-level rates)
  ├── FeeType (Trail / Upfront / ServiceFee)
  ├── RateType (Flat / Tiered)
  ├── Rate (decimal)
  ├── EffectiveDate / ExpiryDate
  └── TenantId

CommissionPayment
  ├── CommissionAgreementId
  ├── Period (month/year)
  ├── CalculatedAmount
  ├── PaidAmount
  ├── PaidAt
  └── Status (Pending / Paid / Disputed)
```

Until then, `AdvisorAccountLink.RebateRate` is the single source of truth.

---

## 10. Entity Relationship Diagram (IFX Revised)

```
Party(AdvisoryFirm) ──[PartyRelationship: ParentFirm]──► Party(AdvisoryBranch)
        │                                                         │
        └──────────────[PartyRelationship: AuthorizedToAdvise]───┤
                                                                  │
                                                            User(Advisor Rep)
                                                       (linked to Branch Party via PartyId)
                                                                  │
                                                    [AdvisorAccountLink]
                                                    ├── EffectiveDate / ExpiryDate
                                                    └── RebateRate
                                                                  │
                                                       InvestmentAccount
                                                    ├── AccountNumber
                                                    ├── AccountType
                                                    └── Status
                                                                  │
                                               [PartyAccountLink]
                                               ├── RelationshipType (RegisteredHolder /
                                               │   BeneficialHolder / TrustBeneficiary /
                                               │   ControllingEntity / Agent)
                                               ├── OwnershipPercentage
                                               └── LinkOrder
                                                                  │
                                                    Party(Investor / Legal Entity)
                                               ├── PartyType (Individual/Company/Trust...)
                                               ├── KYC/AML fields (enriched)
                                               └── InvestorDocuments[]
                                                                  │
                                          [PartyRelationship: self-referential]
                                          ├── BeneficialOwner
                                          ├── ControllingEntity
                                          └── TrustBeneficiary
```

**Legacy ERD (for reference):**
```
AdvisoryGroup ──────────────────────────────────────────────────────────────┐
    │ (1:N)                                                                  │
AdvisoryBranch ─────────────────────────────────────────────────────────────┤
    │ (1:N via AdvisorToGroupLink)                                           │
AdvisorNames ────────────────────────────────────────────────────────────── │
    │ (N:M via AdvisorAccountLink)              (1:N via SupportStaffLink)  │
    │       └── dDateFrom/dDateTo                AdvisorySupportStaff ──────┘
    │       └── decRebateRate
    ▼
INVAccount ─────────────────────────────────────────────────────────────────┐
    │ (N:M via InvestorAccountLink)                                          │
    │       └── kINVInvestorACCRelshpType (Registered/Beneficial/Agent...) │
    │       └── decOwnershipPercentage                                      │
    ▼                                                                        │
INVInvestorNames ────────────────────────────────────────────────────────── │
    │ (self-referential via InvestorInvestorLink)                           │
    │       └── iParentInvestor                                             │
    │       └── kINVInvestorACCRelshpType                                  │
    └──────────────────────────────────────────────────────────────────────┘
         │
         ├── tbl_S_INVPersonalDetails (DOB, sex, DOD)
         ├── tbl_S_INVNationalityResidence (TIN, FATCA, PEP)
         ├── tbl_S_INVInvestorAMLStatus (AML gateway)
         ├── tbl_S_INVAMLPEP (PEP details, source of wealth)
         ├── tbl_S_INVInvestorAddress (addresses)
         └── tbl_S_INVestorContactElec (email/comms)
```

---

## 11. Implementation Roadmap

| Phase | Item | Priority | Notes |
|---|---|---|---|
| 1 | Add `InvestmentAccount` entity to CRM | High | Before Holdings is extended |
| 1 | `PartyAccountLink` (Party → Account, with RelationshipType + OwnershipPct) | High | Replaces current `PartyInvestorRelationship` |
| 1 | Expand `PartyType` enum (AdvisoryFirm, AdvisoryBranch) | High | Small change |
| 1 | `PartyRelationship` table (Party-to-Party) | High | ParentFirm + AuthorizedToAdvise + BeneficialOwner etc. |
| 1 | `AdvisorAccountLink` table | High | With RebateRate, EffectiveDate/ExpiryDate |
| 2 | Enrich `Investor` KYC/AML fields (Section 4.3) | Medium | FrankieOne integration reference |
| 2 | `InvestorDocument` child table | Medium | |
| 2 | OPA ABAC template `HasAdvisoryAuthorization` | Medium | Traverses Party hierarchy |
| 3 | FATCA/CRS full workflow | Low | Regulatory requirement — phase when needed |
| 3 | Commission module | Low | When tiered/split/tracked commission is required |
| Future | Name versioning | Low | Separate versioned names table |
