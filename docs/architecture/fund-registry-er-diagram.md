# Fund Registry — Entity Relationship Diagram

Covers all four Fund Registry modules: **Registry**, **CRM**, **Holdings**, and **Transaction**.

Cross-module references (e.g. `Transaction.ClassId → FundClass.Id`) are logical links — there are no foreign key constraints across module schemas. Integrity is enforced at the Application layer.

```mermaid
erDiagram

  %% ─────────────────────────────────────────
  %% REGISTRY  (schema: registry)
  %% ─────────────────────────────────────────

  Product {
    Guid     Id PK
    Guid     TenantId FK
    string   ProductCode
    string   ProductName
    string   ProductType  "ManagedFund|ETF|Super|IDPS|LIT|Other"
    string   BaseCurrency "ISO 4217"
    string   ApirCode
    string   Isin
    string   RegulatorSchemeNumber "ARSN"
    string   IssuerName
    string   PdsReference
    date     InceptionDate
    date     WindUpDate
    string   Status       "Active|Closed|Suspended"
    datetimeoffset CreatedAt
    datetimeoffset UpdatedAt
  }

  Fund {
    Guid     Id PK
    Guid     TenantId FK
    Guid     ProductId FK "nullable"
    string   FundCode
    string   FundName
    string   FundType  "UCITS|AIF|Hedge|ETF|PrivateEquity|Other"
    string   BaseCurrency
    date     InceptionDate
    string   Status    "Active|Closed"
    datetimeoffset CreatedAt
    datetimeoffset UpdatedAt
  }

  FundClass {
    Guid     Id PK
    Guid     TenantId FK
    Guid     FundId FK
    string   ClassCode
    string   ClassName
    string   Currency
    decimal  MinInitialInvestment
    decimal  ManagementFeeRate
    decimal  PerformanceFeeRate
    string   NavFrequency "Daily|Weekly|Monthly|..."
    string   Status       "Active|Closed"
    datetimeoffset CreatedAt
    datetimeoffset UpdatedAt
  }

  Product ||--o{ Fund : "parent (optional)"
  Fund    ||--o{ FundClass : "classes"

  %% ─────────────────────────────────────────
  %% CRM  (schema: crm)
  %% ─────────────────────────────────────────

  Party {
    Guid   Id PK
    Guid   TenantId FK
    string PartyCode
    string Name
    string LegalStructure "Individual|Corporate|Trust|..."
    string Status         "Active|Closed"
    datetimeoffset CreatedAt
    datetimeoffset UpdatedAt
  }

  PartyRoleAssignment {
    Guid   Id PK
    Guid   PartyId FK
    string Role "Distributor|Custodian|FundManager|Investor|Advisor"
    datetimeoffset CreatedAt
    datetimeoffset UpdatedAt
  }

  Investor {
    Guid   Id PK
    Guid   TenantId FK
    Guid   PartyId FK "nullable"
    string InvestorCode
    string Name
    string LegalStructure
    string KycStatus      "Pending|Approved|Rejected|Expired"
    datetimeoffset KycReviewedAt
    string TaxResidencyCountry
    string TIN
    string FatcaCrsStatus
    string AmlStatus
    string AmlGatewayReference
    bool   IsPEP
    string Status         "Active|Closed"
    datetimeoffset CreatedAt
    datetimeoffset UpdatedAt
  }

  InvestmentAccount {
    Guid   Id PK
    Guid   TenantId FK
    string AccountNumber
    string AccountType "Individual|Joint|Corporate|SMSF|..."
    date   CertificateDate
    string Status      "Active|Inactive|Closed"
    datetimeoffset CreatedAt
    datetimeoffset UpdatedAt
  }

  PartyInvestmentAccountLink {
    Guid   Id PK
    Guid   PartyId FK
    Guid   InvestmentAccountId FK
    datetimeoffset CreatedAt
    datetimeoffset UpdatedAt
  }

  AdvisorInvestmentAccountLink {
    Guid   Id PK
    Guid   AdvisorPartyId FK
    Guid   InvestmentAccountId FK
    datetimeoffset CreatedAt
    datetimeoffset UpdatedAt
  }

  PartyRelationship {
    Guid   Id PK
    Guid   PartyId FK
    Guid   RelatedPartyId FK
    string RelationshipType
    datetimeoffset EffectiveFrom
    datetimeoffset EffectiveTo
    datetimeoffset CreatedAt
    datetimeoffset UpdatedAt
  }

  Party        ||--o{ PartyRoleAssignment         : "roles"
  Party        ||--o| Investor                    : "extends (optional)"
  Party        ||--o{ PartyInvestmentAccountLink  : "accounts"
  Party        ||--o{ AdvisorInvestmentAccountLink: "advises"
  Party        ||--o{ PartyRelationship           : "relationships"
  InvestmentAccount ||--o{ PartyInvestmentAccountLink  : "owners"
  InvestmentAccount ||--o{ AdvisorInvestmentAccountLink: "advisors"

  %% ─────────────────────────────────────────
  %% HOLDINGS  (schema: holdings)
  %% ─────────────────────────────────────────

  Holding {
    Guid    Id PK
    Guid    TenantId FK
    Guid    InvestmentAccountId "→ CRM (logical)"
    Guid    ClassId             "→ FundClass (logical)"
    decimal Units
    string  Status "Active|Closed|Frozen"
    datetimeoffset LastTransactionAt
    datetimeoffset CreatedAt
    datetimeoffset UpdatedAt
  }

  InvestmentAccount ||--o{ Holding : "unit balances (logical)"
  FundClass         ||--o{ Holding : "held in (logical)"

  %% ─────────────────────────────────────────
  %% TRANSACTION  (schema: transaction)
  %% ─────────────────────────────────────────

  Order {
    Guid   Id PK
    Guid   TenantId FK
    string OrderReference "unique per tenant"
    string DealReference  "set on Accept"
    string OrderType      "SubscriptionOrder|RedemptionOrder|SwitchOrder"
    string Status         "Submitted|Accepted|PriceConfirmed|Rejected|Cancelled"
    string RejectionReason
    date   ExpectedTradeDate
    date   ExpectedSettlementDate
    datetimeoffset CreatedAt
    datetimeoffset UpdatedAt
  }

  Transaction {
    Guid    Id PK
    Guid    TenantId FK
    Guid    OrderId FK "nullable — null for legacy"
    string  LegId     "redemption|subscription (Switch legs)"
    string  Type      "Subscription|Redemption|Transfer|Switch"
    Guid    InvestmentAccountId "→ CRM (logical)"
    Guid    FundId              "→ Registry (logical)"
    Guid    ClassId             "→ FundClass (logical)"
    Guid    TargetClassId       "Switch only (logical)"
    decimal Amount
    string  Currency
    decimal Units
    decimal NAVPrice
    date    TradeDate
    date    SettlementDate
    string  Status    "Pending|Processed|Settled|Cancelled|Failed"
    string  FailureReason
    json    ExternalFundIdentifier "type+code (ISIN|APIR|CUSIP|SEDOL)"
    json    DealingPriceDetails    "PriceType+Amount+Currency"
    json    ChargeDetails          "array"
    json    CommissionDetails      "array"
    json    TaxDetails             "array"
    datetimeoffset CreatedAt
    datetimeoffset UpdatedAt
  }

  Order        ||--o{ Transaction    : "legs"
  InvestmentAccount ||--o{ Transaction : "activity (logical)"
  FundClass         ||--o{ Transaction : "traded (logical)"
```

## Module Boundaries

| Module | Schema | Owns |
|--------|--------|------|
| Registry | `registry` | `Product`, `Fund`, `FundClass` |
| CRM | `crm` | `Party`, `PartyRoleAssignment`, `Investor`, `InvestmentAccount`, link tables |
| Holdings | `holdings` | `Holding` |
| Transaction | `transaction` | `Order`, `Transaction` |

> Cross-module references marked **"(logical)"** are `Guid` columns with no FK constraint.
> Referential integrity is enforced at the Application layer via `ICrmReader` and `IRegistryReader`.
