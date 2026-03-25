# CLAUDE.md

This file provides guidance to Claude Code when working with this repository.

## Project Overview

**IFX** is a production-ready ASP.NET Core 8 authentication solution with:
- Clean Architecture (Domain → Application → Infrastructure → Presentation)
- CQRS pattern using MediatR
- OAuth 2.0 Authorization Code flow with PKCE (pluggable identity providers)
- Pluggable identity provider architecture — Cognito and Auth0 adapters, config-driven selection
- Dynamic Multi-IdP SSO with auto-provisioning (database-driven)
- OIDC Discovery for dynamic IdP configuration
- UserInfo-based auto-provisioning (fetches user data from OIDC userinfo endpoint)
- **Multi-tenant** — Tenant and Department entities; Roles, RoleGroups, and IdPs scoped per tenant
- **Template-Based ABAC** — reusable C# condition templates (SameTenant, CreatedByMe) evaluated by a single generic OPA Rego policy; no per-resource Rego files needed for new resource types
- **DB-Backed ABAC Policies** — `PolicyDefinition` table stores tenant-level and platform-level (TenantId = NULL) policy rows; 3-tier resolver: tenant DB → platform DB → static fallback → null (deny)
- Platform services (Background Jobs with Hangfire, Notifications with SendGrid)
- Full audit trail

## Golden Rules

1. **Dependencies flow inward only** - outer layers depend on inner, never reverse
2. **Domain has zero external dependencies** - pure business logic only
3. **Users identified by `(Issuer, Subject)` tuple** - not email alone
4. **One handler per command/query** - no shared handlers
5. **Result pattern for expected failures** - exceptions for unexpected errors
6. **Auth module has three internal subdomains** - Users, Identity, Authorization; new code goes in the correct subdomain folder
7. **Provider-neutral Application layer** - `Auth.Application` must not reference Cognito/Auth0 SDK types; use `IIdentityProvider`, `IOidcAuthService` abstractions
8. **Provider code belongs in `IdentityProviders/`** - Cognito and Auth0 implementations live in `Auth.Infrastructure/IdentityProviders/{Cognito,Auth0}/`; switching provider = config change only

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
| `/.claude/Plans/20260318-merge-ef-migrations.md` | Squash 14 EF migrations into single InitialCreate baseline |
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

## Quick Reference

### Build & Run
```bash
dotnet build IFX.sln          # Build
dotnet test IFX.sln           # Test (466 backend tests → 530 total including frontend)
docker-compose up -d          # Run with Docker

# Frontend tests
cd src/Frontend/IFX.FrontEnd
npm run test:run              # Run 64 frontend tests (Vitest)
npm run test:coverage         # With coverage report
```

### EF Core Migrations
```bash
cd src/Modules/Auth/IFX.Modules.Auth.Infrastructure
dotnet ef migrations add Name --startup-project ../../../ApiHost/IFX.ApiHost
dotnet ef database update --startup-project ../../../ApiHost/IFX.ApiHost
```

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
- Health: `GET /health`, `GET /health/ready`
- Hangfire Dashboard: `GET /hangfire` (background jobs monitoring)

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
