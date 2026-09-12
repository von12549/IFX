# Glossary

## Purpose
Defines terms, abbreviations, and naming conventions used in this codebase.

---

## Core Concepts

| Term | Definition |
|------|------------|
| **User** | Core identity entity, independent of IdP |
| **UserIdentity** | IdP-specific identity data linked to a User |
| **Tenant** | Top-level organisational unit. Roles, RoleGroups, Idps, and Departments all belong to a tenant |
| **Department** | Sub-unit within a tenant; users can be assigned to departments |
| **PrimaryTenantId** | FK on User pointing to the user's default/primary tenant |
| **selectedTenantId** | Frontend (AuthContext) — the currently active tenant; drives all management page list queries |
| **IdP** | Identity Provider (e.g., AWS Cognito, Google) |
| **IdpType** | Classification of IdP: `Internal` (org-managed) or `External` (third-party SSO) |
| **IsPrimary** | Flag indicating the primary IdP for local authentication (only one can be primary) |
| **Subject** | Unique identifier assigned by IdP (the `sub` claim) |
| **Issuer** | URL identifying the IdP (the `iss` claim) |

---

## Abbreviations

| Abbrev | Meaning |
|--------|---------|
| IAM | Identity and Access Management: Identity, Users, Access, Tenancy |
| CQRS | Command Query Responsibility Segregation |
| DDD | Domain-Driven Design |
| DTO | Data Transfer Object |
| IdP | Identity Provider |
| JWT | JSON Web Token |
| JWKS | JSON Web Key Set |
| SSO | Single Sign-On |

---

## Project Naming

| Pattern | Example |
|---------|---------|
| Module namespace | `IFX.Modules.IAM.{Layer}` |
| Command | `RegisterUserCommand` |
| Query | `GetUserProfileQuery` |
| Handler | `RegisterUserCommandHandler` |
| Validator | `RegisterUserCommandValidator` |
| Repository | `IUserRepository` / `UserRepository` |
| Endpoint class | `AuthEndpoints` |
| DTO | `UserProfileDto` |

---

## Fund Registry

| Term | Definition |
|------|------------|
| **Product** | Scheme-level entity — holds regulatory identity (ARSN, APIR, ISIN), issuer name, PDS reference; optional parent of `Fund` via nullable `ProductId` FK |
| **ProductType** | Scheme-level classification: `ManagedFund`, `ETF`, `Superannuation`, `IDPS`, `LIT`, `Other` |
| **ProductStatus** | Scheme lifecycle: `Active`, `Closed`, `Suspended` |
| **Fund** | Investment vehicle (sub-fund); belongs to a `Product` (optional); carries `BaseCurrency`, `FundType`, `InceptionDate`, `Status` |
| **FundType** | Vehicle-level classification: `UCITS`, `AIF`, `Hedge`, `ETF`, `PrivateEquity`, `Other` |
| **FundClass** | Investor-facing unit series within a Fund; carries fee rates, NAV frequency, class currency |
| **NavFrequency** | How often NAV is calculated: `Daily`, `Weekly`, `Monthly`, etc. |
| **Party** | Legal entity (Distributor, Custodian, Fund Manager, Investor, Advisor) with multi-role `PartyRoleAssignment` |
| **Investor** | Extension profile attached to a Party for investment-specific attributes (KYC, risk profile) |
| **InvestmentAccount** | Unit of investment activity; linked to one or more Parties (owners) and Advisors |
| **Holding** | Running unit balance for a `(TenantId, InvestmentAccountId, FundClassId)` triple; read-only via HTTP |
| **Transaction** | State-machine record for subscription, redemption, transfer, or switch; transitions Pending → Processed → Settled; may be an Order leg (OrderId set) or a standalone legacy transaction (OrderId null) |
| **Order** | Aggregate root representing an investor instruction (Calastone STP pattern); wraps one or more Transaction legs; lifecycle: Submitted → Accepted → PriceConfirmed \| Rejected \| Cancelled |
| **OrderType** | `SubscriptionOrder`, `RedemptionOrder`, `SwitchOrder` |
| **OrderStatus** | `Submitted`, `Accepted`, `PriceConfirmed`, `Rejected`, `Cancelled` |
| **OrderReference** | Ordering-party external reference for the Order (unique per tenant) |
| **DealReference** | Executing-party reference set on Accept (e.g. Calastone deal ref) |
| **ExternalFundIdentifier** | Value object: identifier type (ISIN/APIR/CUSIP/SEDOL/OTHER) + identifier string; stored on Transaction leg |
| **DealingPriceDetails** | Owned type on Transaction leg: PriceType + Amount + Currency; populated on Order Confirm |
| **TransactionProcessedEvent** | Integration event published after `Process(navPrice)` or Order `Confirm` — triggers Holdings update |
| **STP** | Straight-Through Processing — automated fund order routing without manual intervention; Calastone is the industry STP network |
| **Calastone** | Fund industry STP network; IFX acts as an Executing Party in the Calastone REST API V3.0 model |
| **ARSN** | Australian Registered Scheme Number — scheme-level regulatory identifier |
| **APIR** | Australian Product Identification Reference — 9-character fund identifier |
| **ISIN** | International Securities Identification Number — ISO 6166 12-character identifier |
| **PDS** | Product Disclosure Statement — regulatory document reference stored at Product level |

---

## Database

| Term | Definition |
|------|------------|
| Schema | Modules use separate schemas: `auth`, `crm`, `registry`, `holdings`, `transaction` |
| Aggregate Root | Entity that owns other entities (User owns UserIdentities; Product owns Funds navigation) |
| Owned Entity | Entity stored in same table as owner (DeviceInfo in LoginEvent) |

---

## Authentication

| Term | Definition |
|------|------------|
| Access Token | Short-lived JWT for API access |
| Refresh Token | Long-lived token to obtain new access tokens |
| Claims Transformation | Process of adding database role to JWT claims |

---

## ABAC Authorization

Current policy and failure semantics: [Plan 05 implementation](../docs/architecture/review/iam-platform-security.en.md).

| Term | Definition |
| --- | --- |
| ABAC | Authorization using bounded subject, resource and environment facts |
| RBAC | Current IAM role/permission grants combined with mandatory constraints and applicable ABAC |
| PolicyDefinition | IAM-owned scoped policy data, validated and versioned from current content |
| Platform policy | Explicit platform-scope policy; does not grant tenant membership |
| OPA | Technical Rego evaluation provider behind Platform.Authorization Contracts |
| Fail closed | Missing required facts, invalid policy or unavailable evaluation never widen access |

The former policy cache and always-allow OPA client are retired, not supported extension points.
