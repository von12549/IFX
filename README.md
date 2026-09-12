# IFX

An ASP.NET Core 8 modular monolith with Clean Architecture, CQRS, dynamic multi-IdP SSO, and a Fund Registry system (CRM, Registry, Holdings, Transaction modules) with a three-tier Product → Fund → FundClass hierarchy.

Current architecture: [中文](docs/architecture/review/iam-platform-security.zh-CN.md) · [English](docs/architecture/review/iam-platform-security.en.md) · [Plan 05 evidence](docs/architecture/review/evidence/plan05/README.md).

## Features

### Architecture
- **Clean Architecture** — Domain, Application, Infrastructure, Presentation layers with inward-only dependencies
- **CQRS** — Command/Query separation via MediatR; one handler per operation

### Authentication & SSO
- **OAuth 2.0 with PKCE** — Authorization Code flow; pluggable identity provider adapters
- **Pluggable Identity Providers** — Cognito and Auth0 adapters selected via `Authentication:Provider`; see implementation notes for the inherited Auth0 password-login limitation and pending live-provider validation
- **Dynamic Multi-IdP SSO** — Database-driven IdP configuration; multiple providers per tenant
- **OIDC Discovery** — Automatic IdP configuration via well-known endpoints
- **UserInfo-Based Provisioning** — Fetches user profile from OIDC userinfo endpoint during auto-provisioning

### Multi-Tenancy
- **Tenant & Department entities** — Roles, RoleGroups, and IdPs are all scoped per tenant
- **Tenant switcher** — React UI tenant switcher drives all admin list views via `X-Tenant-Id` header

### Authorization
- **Role-Based Access Control** — Current IAM user, membership and grants reloaded at authorization gates; external role claims do not grant local access
- **ABAC via OPA** — Open Policy Agent for fine-grained, resource-level policy decisions layered on top of RBAC; evaluation errors and disabled OPA fail closed
- **Template-Based ABAC** — Reusable C# condition templates (SameTenant, CreatedByMe) evaluated by a single generic Rego policy; no per-resource Rego files needed for new resource types
- **DB-Backed Policies** — Scoped policies with content-derived versions; documented absence permits defaults, disabled/invalid/unavailable policies deny
- **GlobalRole system** — Explicit platform-scope grants for PlatformAdmin/PlatformSupport/PlatformAuditor; tenant access still requires current membership and applicable RBAC/ABAC

### User Management
- **Full Audit Trail** — Login/logout events, activity logs, registration tracking
- **User Profile** — Self-service profile editing including primary tenant selection (multi-tenant users)

### Fund Registry
- **CRM** — Party (with multi-role `PartyRoleAssignment`), Investor (with extension profiles), and `InvestmentAccount` as the unit of investment activity; Party↔Account and Party↔Party relationships; user-party links; KYC tracking
- **Registry** — Three-tier Product (Scheme) → Fund → FundClass hierarchy; Product holds regulatory identity (ARSN, APIR, ISIN), issuer metadata, and PDS reference; Fund carries BaseCurrency, FundType, and lifecycle status; FundClass holds fee rates, NAV frequency, and class currency; `Fund.ProductId` is optional so standalone funds remain valid
- **Holdings** — Authoritative unit ledger per (InvestmentAccount, FundClass); read-only HTTP; mutated exclusively via integration events
- **Transaction** — Subscription, Redemption, Transfer, and Switch processing; cross-module KYC + class-status validation; `Process(navPrice)` calculates units and triggers Holdings update
- **Order Instruction Model** — `Order` aggregate root wrapping `Transaction` legs; Calastone STP pattern; lifecycle: Submitted → Accepted → PriceConfirmed | Rejected | Cancelled; external fund identifiers (ISIN/APIR/CUSIP/SEDOL); charge/commission/tax detail columns

### Platform Services
- **Integration Events** — Reliable Outbox/Inbox delivery with versioned module Contracts and provider adapters
- **Background Jobs** — Hangfire with fire-and-forget, delayed, and recurring job support
- **Email Notifications** — SendGrid with HTML/plain-text, templated, and batch sending

### Developer Experience
- **Automated verification** — Backend, SQL Server, frontend and architecture gates; current counts and limitations are in [Plan 05 evidence](docs/architecture/review/evidence/plan05/P05-S7-release-validation.md)
- **DateTimeOffset throughout** — all timestamps use `DateTimeOffset` (not `DateTime`); SQL columns are `datetimeoffset(7)`; JSON responses carry explicit UTC offset (`+00:00`)
- **Docker Support** — Full stack via `docker-compose up -d` (API + Frontend + SQL Server + OPA)
- **React Frontend** — Admin UI with role-differentiated views: tenant-scoped CRUD for standard users; GlobalRole users get platform Sidebar nav, permission/policy scope tabs, and lazy-loaded cross-tenant data sections on every management page
- **Demo UI** — Minimal HTML/JS client for testing the OAuth flow end-to-end

## Quick Start

```bash
# Clone and configure
git clone <repository-url>
cd AuthSample

# Run with Docker
docker-compose up -d

# Access
# API: http://localhost:5010
# Swagger: http://localhost:5010/swagger
```

See [Getting Started](docs/development/getting-started.md) for detailed setup.

## Project Structure

```
src/
├── ApiHost/IFX.ApiHost/             # API / Worker runtime roles
├── DatabaseMigrator/               # Controlled schema migration
├── BuildingBlocks/                 # Application/context/composition/security primitives
├── Modules/
│   ├── IAM/                        # Identity, Users, Access, Tenancy
│   ├── CRM/                        # Party, Investor, InvestmentAccount
│   ├── Registry/                   # Product, Fund, FundClass
│   ├── Holdings/                   # Unit ledger
│   └── Transaction/                # Orders and transactions
│       # Each module: Domain, Application, Infrastructure,
│       # Presentation, Composition, versioned Contracts
├── Platform/
│   ├── Authentication/             # Contracts, Runtime, Cognito/Auth0, Composition
│   ├── Authorization/              # Contracts, Runtime, OPA, Composition
│   ├── Messaging/                  # Reliable delivery and adapters
│   ├── BackgroundJobs/             # Hangfire and persisted type aliases
│   └── Notifications/              # Email delivery
├── Frontend/IFX.FrontEnd/           # React and Vitest
└── WebUI/IFX.WebUI/                 # Demo OAuth client
tests/                             # Unit, integration, SQL and boundary tests
mcp/LayerGuard/                    # Boundary checker and tests
tools/IFX.DatabaseInventory/       # Governed database/migration inventory
```

## API Overview

| Category | Endpoints |
|----------|-----------|
| **OAuth** | `GET /api/v1/auth/oauth/{authorize,callback,userinfo,logout}` |
| Public | `POST /api/v1/auth/{register,confirm,login}` |
| Authenticated | `POST /api/v1/auth/{logout,refresh,revoke}`, `/api/v1/user/*` |
| Admin — Users | `GET/PUT /api/v1/usermanagement/users` |
| Admin — Auth | `/api/v1/role`, `/api/v1/rolegroup`, `/api/v1/idp` |
| Admin — Tenants | `GET/POST/PUT/DELETE /api/v1/tenant` |
| Admin — Departments | `GET/POST/PUT/DELETE /api/v1/department` |
| Admin — Tenant Policies | `GET/POST/PUT/DELETE /api/v1/policy`, `GET /api/v1/policy/templates` |
| Admin — Platform Policies | `GET/POST/PUT/DELETE /api/v1/platform/policy` |
| Platform — GlobalRoles | `GET /api/v1/platform/globalroles`, `GET/POST/DELETE /api/v1/platform/users/{id}/globalroles` |
| Platform — Cross-Tenant | `GET /api/v1/platform/cross-tenant/{users,roles,rolegroups,departments,idps}` |
| CRM — Parties | `GET/POST /api/v1/party`, `GET/PUT/DELETE /api/v1/party/{id}`, `GET/POST/DELETE /api/v1/party/{id}/roles/{role}`, `POST /api/v1/party/{id}/relationships`, `POST/DELETE /api/v1/party/{id}/users/{userId}` |
| CRM — Investors | `GET/POST /api/v1/investor`, `GET/PUT/DELETE /api/v1/investor/{id}`, `PUT /api/v1/investor/{id}/kyc` |
| CRM — InvestmentAccounts | `GET/POST /api/v1/investment-account`, `GET/PUT/DELETE /api/v1/investment-account/{id}`, party/advisor link/unlink sub-routes |
| Registry — Products | `GET/POST /api/v1/product`, `GET/PUT/DELETE /api/v1/product/{id}`, `GET /api/v1/product/{id}/funds` |
| Registry — Funds | `GET/POST /api/v1/fund`, `GET/PUT/DELETE /api/v1/fund/{id}` (optional `ProductId`) |
| Registry — Classes | `GET/POST /api/v1/fund/{fundId}/class`, `GET/PUT/DELETE /api/v1/fund/{fundId}/class/{id}` |
| Holdings | `GET /api/v1/holding`, `/holding/{id}`, `/investor/{investmentAccountId}/holdings`, `/fund/{id}/class/{id}/holdings` |
| Transactions | `GET/POST /api/v1/transaction`, `POST /transaction/{subscription,redemption,transfer,switch}`, `POST /transaction/{id}/{process,cancel}` |
| Orders (STP) | `GET/POST /api/v1/order`, `GET /api/v1/order/{id}`, `POST /api/v1/order/{id}/{accept,reject,confirm}`, `DELETE /api/v1/order/{id}` |
| Health | `GET /health`, `GET /health/ready` |
| Jobs | `GET /hangfire` (dashboard) |

> **Tenant filtering:** list endpoints read the selected tenant from the `X-Tenant-Id` request header. The frontend sends this header automatically via the axios interceptor (value persisted in `localStorage`). Omitting the header returns an empty result.

### OAuth Flow (Recommended)

```
GET /api/v1/auth/oauth/authorize?response_mode=json
→ Returns { authorizationUrl, state }
→ Redirect user to authorizationUrl (Cognito Hosted UI)
→ After login, redirects to callback with tokens
```

See [API Reference](docs/api/endpoints.md) for full documentation.

## Platform Services

### Background Jobs (Hangfire)

```csharp
public class MyService
{
    private readonly IBackgroundJobService _jobs;

    public void ScheduleWork()
    {
        // Fire-and-forget
        _jobs.Enqueue<IEmailService>(x => x.SendEmailAsync(message));

        // Delayed
        _jobs.Schedule<IReportService>(x => x.Generate(), TimeSpan.FromHours(1));

        // Recurring (cron)
        _jobs.AddOrUpdateRecurring<ICleanupService>("cleanup", x => x.Run(), "0 0 * * *");
    }
}
```

### Email Notifications (SendGrid)

```csharp
public class MyService
{
    private readonly IEmailService _email;

    public async Task SendWelcome(string userEmail)
    {
        await _email.SendEmailAsync(new EmailMessage
        {
            To = userEmail,
            Subject = "Welcome!",
            HtmlBody = "<h1>Welcome to our app!</h1>"
        });
    }
}
```

Configuration in `appsettings.json`:
```json
{
  "BackgroundJobs": { "ConnectionString": "..." },
  "Notifications": {
    "SendGrid": {
      "ApiKey": "SG.xxx",
      "DefaultFromEmail": "noreply@example.com"
    }
  }
}
```

## Development

```bash
# Build
dotnet build IFX.sln

# Backend tests (765)
dotnet test IFX.sln

# Coverage report
dotnet test IFX.sln --collect:"XPlat Code Coverage"
reportgenerator -reports:"coverage-results/**/coverage.cobertura.xml" \
  -targetdir:"coverage-report" -reporttypes:"Html;TextSummary" \
  -assemblyfilters:"+IFX.*;-*Tests*"

# Frontend tests (64)
cd src/Frontend/IFX.FrontEnd
npm run test:run       # run once
npm run test:coverage  # with coverage

# Run API locally
cd src/ApiHost/IFX.ApiHost
dotnet run

# Run Demo UI (optional)
cd src/WebUI/IFX.WebUI
python -m http.server 3000
# Open http://localhost:3000
```

## Documentation

### Architecture & Development
- [Architecture Overview](docs/architecture/index.md)
- [Database Schema](docs/architecture/database.md)
- [Getting Started](docs/development/getting-started.md)
- [API Reference](docs/api/endpoints.md)

### Setup Guides
- [Cognito Managed Login (OAuth)](docs/Plans/cognito-managed-login.md)
- [SSO Multi-IdP Authentication](docs/sso-multi-idp.md)
- [Auto-Provisioning Strategy](docs/architecture/auto-provisioning.md)
- [AWS Cognito Setup](docs/AWS_COGNITO_SETUP.md)
- [Multi-IdP Migration](docs/MULTI_IDP_MIGRATION_SUMMARY.md)

## Technology Stack

- .NET 8, ASP.NET Core 8, EF Core 8
- MediatR, FluentValidation, AutoMapper
- AWS SDK (Cognito) · Auth0 (stub adapter ready), Serilog, Swagger
- Hangfire (background jobs), SendGrid (email)
- OPA (Open Policy Agent) for ABAC authorization
- SQL Server, Docker
- React 18, TypeScript, Vite (frontend)

## Contributing

1. Fork the repository
2. Create a feature branch
3. Submit a Pull Request

## License

MIT License
