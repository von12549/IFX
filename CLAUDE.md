# CLAUDE.md

This file provides guidance to Claude Code when working with this repository.

Current IAM/security ownership and compatibility rules: [Plan 05 implementation](docs/architecture/review/iam-platform-security.en.md). Auth project directories are retired; do not recreate them. Historical plans are migration records, not current implementation instructions.

## Project Overview

**IFX** is an ASP.NET Core 8 modular monolith with:
- Clean Architecture (Domain → Application → Infrastructure → Presentation)
- CQRS pattern using MediatR
- OAuth 2.0 Authorization Code flow with PKCE (pluggable identity providers)
- Pluggable identity provider architecture — Cognito and Auth0 adapters, config-driven selection
- Dynamic Multi-IdP SSO with auto-provisioning (database-driven)
- OIDC Discovery for dynamic IdP configuration
- UserInfo-based auto-provisioning (fetches user data from OIDC userinfo endpoint)
- **Multi-tenant** — Tenant and Department entities; Roles, RoleGroups, and IdPs scoped per tenant
- **Template-Based ABAC** — reusable C# condition templates (SameTenant, CreatedByMe) evaluated by a single generic OPA Rego policy; no per-resource Rego files needed for new resource types
- **DB-Backed ABAC Policies** — `PolicyDefinition` table stores tenant-level and platform-level (TenantId = NULL) policy rows; current scoped resolution: documented absence may use defaults; disabled, invalid or unavailable policies deny
- **GlobalRole system** — cross-tenant PlatformAdmin/PlatformSupport/PlatformAuditor roles; explicit platform-scope grants; tenant access still requires current IAM membership and applicable RBAC/ABAC
- **GlobalRole frontend views** — dual-section UI: tenant data in main table, lazy-loaded `ExpandableCrossTenantSection` for other tenants; platform Sidebar nav, permission/policy scope tabs, `TenantRequiredBanner`
- **Fund Registry** — CRM (Party/Investor/InvestmentAccount), Registry (Product→Fund→FundClass three-tier hierarchy), Holdings (unit ledger), Transaction (sub/redeem/transfer/switch) modules
- **Product layer** — `Product` (Scheme) is the optional regulatory parent of `Fund`; holds ARSN, APIR, ISIN, issuer name, PDS reference; `Fund.ProductId` is nullable so standalone funds remain valid
- **Order Instruction Model** — `Order` aggregate root as investor instruction (Calastone STP layer); `Order → Transaction` legs hierarchy; accept/reject/confirm workflow; external fund identifiers (ISIN/APIR); charge/commission/tax details
- **DateTimeOffset** — all audit (`CreatedAt`/`UpdatedAt`) and domain timestamp fields use `DateTimeOffset` throughout; SQL Server stores `datetimeoffset(7)` columns
- Platform services (Background Jobs with Hangfire, Notifications with SendGrid)
- Full audit trail

## Golden Rules

1. **Dependencies flow inward only** - outer layers depend on inner, never reverse
2. **Domain has zero external dependencies** - pure business logic only
3. **Users identified by `(Issuer, Subject)` tuple** - not email alone
4. **One handler per command/query** - no shared handlers
5. **Result pattern for expected failures** - exceptions for unexpected errors
6. **IAM has four internal subdomains** - Identity, Users, Access, Tenancy; new code goes under `src/Modules/IAM` in the owning subdomain
7. **Provider-neutral Application layer** - IAM.Application defines its own ports; IAM.Infrastructure adapters consume Platform Contracts, not provider SDK types in Application
8. **Platform owns protocol execution** - Cognito/Auth0 adapters live in `Platform/Authentication`; OPA evaluation lives in `Platform/Authorization`. IAM owns IdP trust, local admission and policy composition
9. **Use `DateTimeOffset`, never `DateTime`** - all timestamps (audit fields, domain events, DTOs) must be `DateTimeOffset`; `SaveChangesAsync` assigns `DateTimeOffset.UtcNow`

## Instruction Index

| Document | Purpose |
|----------|---------|
| `/.claude/architecture.md` | Layer responsibilities, dependency rules, patterns |
| `/.claude/coding-standards.md` | Naming conventions, error handling, logging |
| `/.claude/decisions.md` | Key architectural decisions with rationale |
| `/.claude/glossary.md` | Terms, abbreviations, naming patterns |
| `/.claude/dotnet/overview.md` | Tech stack, build/run commands |
| `/.claude/dotnet/cqrs.md` | Command/Query patterns, adding new operations |
| `/.claude/dotnet/ef-core.md` | Database schema, migrations |
| `/.claude/dotnet/testing.md` | Test structure, patterns |
| `/.claude/dotnet/aws-cognito.md` | Cognito configuration, auth flows |
| `/.claude/Plans/cognito-managed-login.md` | OAuth 2.0 / Cognito Managed Login implementation |
| `/docs/architecture/auto-provisioning.md` | SSO auto-provisioning strategy and flow |
| `/.claude/Plans/auto-provision-oauth-improvements.md` | UserInfo-based provisioning with Pending role |
| `/.claude/Plans/20260120-platform-module.md` | Platform module (BackgroundJobs, Notifications) |
| `/.claude/playbooks/git-workflow.md` | Git branching, commits, PR workflow |
| `/.claude/playbooks/naming-conventions.md` | Code artifact naming patterns |
| `/.claude/playbooks/pattern-selection.md` | Platform vs Modules pattern decision guide |
| `/.claude/Plans/20260316-auth-subdomain-refactor.md` | Auth module subdomain structure (Users, Identity, Authorization) |
| `/.claude/Plans/20260316-pluggable-identity-providers.md` | Pluggable identity provider architecture (Cognito/Auth0 adapters) |
| `/.claude/Plans/20260318-merge-ef-migrations.md` | Squash 14 EF migrations into single InitialCreate baseline (superseded) |
| `/.claude/Plans/20260327-merge-ef-migrations-uuid-v7.md` | Squash 10 EF migrations into InitialCreate + InitialSeed with UUID v7 seed IDs |
| `/.claude/Plans/20260321-frontend-ifx.md` | IFX.FrontEnd React app — pages, API audit, token flow, implementation order |
| `/.claude/Plans/20260322-test-coverage-improvement.md` | Unit + integration + frontend test coverage improvement (Phases 1–8) |
| `/.claude/Plans/20260322-multi-tenant.md` | Multi-tenant support — Tenant/Department entities, TenantId on Role/RoleGroup/Idp, CRUD endpoints, tenant-filtered queries, frontend pages |
| `/.claude/Plans/20260323-opa-abac-authorization.md` | OPA + ABAC authorization — IResourceAuthorizationService, OpaClient, Rego policies, pilot use case |
| `/.claude/Plans/20260324-template-abac.md` | Template-based ABAC engine — reusable condition templates, single generic Rego, DB-backed policy storage |
| `/.claude/Plans/20260325-db-backed-abac-policies.md` | DB-backed tenant-level ABAC policies — PolicyDefinition entity, CRUD endpoints, cache invalidation |
| `/.claude/Plans/20260325-seed-user-policies-ifx-tenant.md` | Seed user/read ABAC policy for IFX tenant via EF migration |
| `/.claude/Plans/20260325-global-platform-abac-policies.md` | Platform-level (TenantId=NULL) ABAC policies — 3-tier resolver, platform CRUD endpoints |
| `/.claude/Plans/20260325-complete-abac-policies.md` | Complete ABAC coverage — IsActive template, CreatedBy DB column, resource attribute models, per-handler policies, list gate strategy, seeded PolicyDefinitions |
| `/.claude/Plans/20260326-policy-definition-scope.md` | PolicyDefinition Scope field — replace TenantId=NULL convention with explicit Scope enum (Platform/Tenant), unique index update, resolver refactor |
| `/.claude/Plans/20260326-global-roles.md` | GlobalRole system — cross-tenant PlatformAdmin/Support/Auditor roles, AnyTenant OPA template, platform policy dispatch, CRUD endpoints |
| `/.claude/Plans/20260326-auth-authorization-feature-subfolders.md` | Authorization subdomain feature-subfolder refactor — Roles, RoleGroups, Permissions, Tenants, Departments each get Commands/Queries/DTOs/Authorization subfolders |
| `/.claude/Plans/20260326-frontend-global-role-views.md` | Frontend GlobalRole views — dual-section layout for GlobalRole users, cross-tenant data grouping, permission/policy scope split, Phase 1 (no new endpoints) + Phase 2 (cross-tenant endpoints) |
| `/.claude/Plans/20260401-fund-registry-crm-registry-holdings-transaction.md` | Fund Registry System — CRM (Party/Investor), Registry (Fund/Class), Holdings (unit ledger), Transaction (sub/redeem/transfer/switch) modules with Option B integration events |
| `/.claude/Plans/20260413-crm-v2-investment-account-party-relationship-kyc.md` | CRM V2 — InvestmentAccount entity, PartyRelationship, advisor model, KYC enrichment; migrates Holding/Transaction from InvestorId → InvestmentAccountId |
| `/.claude/Plans/20260413-ef-migration-pipeline-crm-holdings-transaction-registry.md` | Replace EnsureCreatedAsync with MigrateAsync in CRM, Holdings, Transaction, Registry — squashed InitialCreate baselines + EnsureCreatedAsync→MigrateAsync stamping logic |
| `/.claude/Plans/20260414-registry-product-layer.md` | Registry Product layer — Product (Scheme) → Fund → FundClass three-tier hierarchy; nullable ProductId FK on Fund; new CRUD endpoints + integration events |
| `/.claude/Plans/20260416-pricing-distribution-commission-billing.md` | Future modules — Pricing (UnitPrice/NAV), Distribution, Commission, Billing, Operations; entity designs, batch jobs, cross-module dependencies, implementation order |
| `/.claude/Plans/20260418-order-instruction-model.md` | Order Instruction Model — Calastone STP integration layer; Order → Transaction legs hierarchy; accept/reject/confirm workflow; external fund identifiers (ISIN/APIR); charge/commission/tax details |
| `/.claude/Plans/20260418-datetimeoffset-migration.md` | DateTimeOffset Migration — replace all `DateTime` audit/domain fields with `DateTimeOffset` across 5 modules; EF migrations per DbContext; zero functional change |

## Quick Reference

### Build & Run
```bash
dotnet build IFX.sln          # Build
dotnet test IFX.sln           # Test (current counts: Plan 05 evidence)
docker-compose up -d          # Run with Docker

# Frontend tests
cd src/Frontend/IFX.FrontEnd
npm run test:run              # Run frontend tests (Vitest)
npm run test:coverage         # With coverage report
```

### EF Core Migrations
```bash
cd src/Modules/IAM/IFX.Modules.IAM.Infrastructure
dotnet ef migrations add Name --context IfxDbContext --startup-project ../../../ApiHost/IFX.ApiHost
```

Apply migrations through the controlled [DatabaseMigrator workflow](scripts/Invoke-DatabaseMigrator.ps1), with target connections selected explicitly. Preserve `auth`, `AuthDatabase`, migration IDs and the exact legacy Hangfire alias documented in Plan 05.

### API Endpoints
- OAuth: `GET /api/v1/auth/oauth/{authorize,callback,userinfo,logout}`
- Public: `POST /api/v1/auth/{register,confirm,login}` (login deprecated, use OAuth)
- Authenticated: `POST /api/v1/auth/{logout,refresh,revoke}`, `GET/PUT /api/v1/user/profile`
- Admin — Users: `GET/PUT /api/v1/usermanagement/users` (tenant via `X-Tenant-Id` header)
- Admin — Auth: `GET/POST/PUT /api/v1/role`, `/api/v1/rolegroup`, `/api/v1/idp` (tenant via `X-Tenant-Id` header)
- Admin — Tenants: `GET/POST/PUT/DELETE /api/v1/tenant`
- Admin — Departments: `GET/POST/PUT/DELETE /api/v1/department` (tenant via `X-Tenant-Id` header)
- Admin — Tenant Policies: `GET/POST/PUT/DELETE /api/v1/policy` + `GET /api/v1/policy/templates` (tenant via `X-Tenant-Id`; requires `Policy:list`/`Policy:create`/`Policy:update`/`Policy:delete`)
- Admin — Platform Policies: `GET/POST/PUT/DELETE /api/v1/platform/policy` (requires `Platform.Policy:list`/`Platform.Policy:create`/`Platform.Policy:update`/`Platform.Policy:delete`)
- Platform — GlobalRoles: `GET /api/v1/platform/globalroles`, `GET/POST/DELETE /api/v1/platform/users/{userId}/globalroles/{roleId}` (requires `Platform.GlobalRole:manage`)
- Platform — Cross-Tenant: `GET /api/v1/platform/cross-tenant/{users,roles,rolegroups,departments,idps}` (requires `Platform.GlobalRole:manage`; returns data grouped by tenant, excluding caller's tenant)
- Health: `GET /health`, `GET /health/ready`
- Hangfire Dashboard: `GET /hangfire` (background jobs monitoring)
- CRM — Parties: `GET/POST /api/v1/party`, `GET/PUT/DELETE /api/v1/party/{id}`, `GET /api/v1/party/{id}/investors`, `GET/POST/DELETE /api/v1/party/{id}/roles/{role}`, `POST /api/v1/party/{id}/relationships`, `PUT /api/v1/party/{id}/relationships/{relId}/expire`, `POST/DELETE /api/v1/party/{id}/users/{userId}` (tenant via `X-Tenant-Id`)
- CRM — Investors: `GET/POST /api/v1/investor`, `GET/PUT/DELETE /api/v1/investor/{id}`, `PUT /api/v1/investor/{id}/kyc` (tenant via `X-Tenant-Id`)
- CRM — InvestmentAccounts: `GET/POST /api/v1/investment-account`, `GET/PUT/DELETE /api/v1/investment-account/{id}`, `POST/DELETE /api/v1/investment-account/{id}/parties/{partyId}`, `POST/DELETE /api/v1/investment-account/{id}/advisors/{advisorPartyId}` (tenant via `X-Tenant-Id`)
- Registry — Products: `GET/POST /api/v1/product`, `GET/PUT/DELETE /api/v1/product/{id}`, `GET /api/v1/product/{id}/funds` (tenant via `X-Tenant-Id`)
- Registry — Funds: `GET/POST /api/v1/fund`, `GET/PUT/DELETE /api/v1/fund/{id}` (tenant via `X-Tenant-Id`; optional `ProductId` on create/update)
- Registry — Classes: `GET/POST /api/v1/fund/{fundId}/class`, `GET/PUT/DELETE /api/v1/fund/{fundId}/class/{id}` (tenant via `X-Tenant-Id`)
- Holdings (read-only): `GET /api/v1/holding`, `GET /api/v1/holding/{id}`, `GET /api/v1/investor/{investmentAccountId}/holdings`, `GET /api/v1/fund/{fundId}/class/{classId}/holdings` (tenant via `X-Tenant-Id`)
- Transactions: `GET/POST /api/v1/transaction`, `GET /api/v1/transaction/{id}`, `POST /api/v1/transaction/{subscription,redemption,transfer,switch}`, `POST /api/v1/transaction/{id}/{process,cancel}` (tenant via `X-Tenant-Id`)
- Orders (STP): `POST /api/v1/order`, `GET /api/v1/order`, `GET /api/v1/order/{id}`, `POST /api/v1/order/{id}/{accept,reject,confirm}`, `DELETE /api/v1/order/{id}` (tenant via `X-Tenant-Id`; requires `Order:create`/`Order:read`/`Order:update`/`Order:delete`)

> **Tenant filtering:** list endpoints read the selected tenant from the `X-Tenant-Id` request header. The frontend sends this header automatically via the `apiClient` interceptor (value persisted in `localStorage`). No `TenantId` is passed in query params or command bodies for list queries — the handler reads it from `ICurrentUser.TenantId`.

### Platform Services
- **BackgroundJobs**: `IBackgroundJobService` - Enqueue, Schedule, Recurring jobs (Hangfire)
- **Notifications**: `IEmailService` - SendEmail, SendTemplatedEmail, SendBatch (SendGrid)

## Conflict Resolution

If instructions conflict, prioritize:
1. Security/compliance
2. Architecture invariants (see `architecture.md`)
3. Module-specific rules
4. Style preferences

## When Uncertain

Load the most relevant `/.claude/*` document before making changes.

## Maintenance Rules
- CLAUDE.md maintenance must follow `/.claude/playbooks/claude-splitting-playbook.md`
- README.md maintenance must follow `/.claude/playbooks/readme-playbook.md`
- Git operations must follow `/.claude/playbooks/git-workflow.md`
- Naming conventions must follow `/.claude/playbooks/naming-conventions.md`
- Pattern selection (Platform vs Modules) must follow `/.claude/playbooks/pattern-selection.md`
- **Planning**: Before implementing any feature, save the plan to `/.claude/Plans/YYYYMMDD-feature-name.md`
