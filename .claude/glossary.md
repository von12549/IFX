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
| Module namespace | `IFX.Modules.Auth.{Layer}` |
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
| **Transaction** | State-machine record for subscription, redemption, transfer, or switch; transitions Pending → Processed → Settled |
| **TransactionProcessedEvent** | Integration event published after `Process(navPrice)` — triggers Holdings update |
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

| Term | Definition |
|------|------------|
| **ABAC** | Attribute-Based Access Control — resource-level authorization based on subject/resource attributes |
| **RBAC** | Role-Based Access Control — coarse-grained permission gate (checked before ABAC) |
| **ConditionTemplate** | Named reusable rule (e.g. `SameTenant`) with left/operator/right field references |
| **AbacPolicy** | Ordered list of `AbacCondition` objects; all must pass (AND semantics) |
| **AbacCondition** | One condition in a policy, bound to a `ConditionTemplate` with optional parameters |
| **PolicyDefinition** | DB entity storing a policy row; `TenantId = null` = platform-level (global default) |
| **Platform policy** | `PolicyDefinition` with `TenantId IS NULL` — applies to all tenants without a tenant-specific override |
| **Tenant policy** | `PolicyDefinition` with a specific `TenantId` — overrides the platform default for that tenant |
| **3-tier resolver** | Resolution order: tenant DB row → platform DB row → static fallback → null (deny) |
| **IAbacPolicyCache** | Interface for invalidating cached policy entries after create/update/delete |
| **StaticAbacPolicyResolver** | In-memory fallback resolver for resources not yet stored in the DB |
| **OPA** | Open Policy Agent — external sidecar evaluating Rego policies for fine-grained decisions |
| **Rego** | Policy language used by OPA; template-based resources use a single `template_abac.rego` |
| **NullOpaPolicyClient** | Dev stub that always allows; registered when `Opa:Enabled = false` |
| **FailClosed** | Default behavior: OPA unavailability = deny (not allow) |
