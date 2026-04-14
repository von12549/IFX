# IFX

A production-ready ASP.NET Core 8 modular monolith with Clean Architecture, CQRS, dynamic multi-IdP SSO, and a Fund Registry system (CRM, Registry, Holdings, Transaction modules) with a three-tier Product → Fund → FundClass hierarchy.

## Features

### Architecture
- **Clean Architecture** — Domain, Application, Infrastructure, Presentation layers with inward-only dependencies
- **CQRS** — Command/Query separation via MediatR; one handler per operation

### Authentication & SSO
- **OAuth 2.0 with PKCE** — Authorization Code flow; pluggable identity provider adapters
- **Pluggable Identity Providers** — Cognito and Auth0 adapters; switch provider via `Authentication:Provider` config
- **Dynamic Multi-IdP SSO** — Database-driven IdP configuration; multiple providers per tenant
- **OIDC Discovery** — Automatic IdP configuration via well-known endpoints
- **UserInfo-Based Provisioning** — Fetches user profile from OIDC userinfo endpoint during auto-provisioning

### Multi-Tenancy
- **Tenant & Department entities** — Roles, RoleGroups, and IdPs are all scoped per tenant
- **Tenant switcher** — React UI tenant switcher drives all admin list views via `X-Tenant-Id` header

### Authorization
- **Role-Based Access Control** — Admin, User, SsoUser, Pending roles with JWT claims transformation
- **ABAC via OPA** — Open Policy Agent for fine-grained, resource-level policy decisions layered on top of RBAC; fail-closed by default
- **Template-Based ABAC** — Reusable C# condition templates (SameTenant, CreatedByMe) evaluated by a single generic Rego policy; no per-resource Rego files needed for new resource types
- **DB-Backed Policies** — `PolicyDefinition` table stores tenant-level and platform-level rows; 3-tier resolver: tenant DB → platform DB → static fallback → deny
- **GlobalRole system** — Cross-tenant PlatformAdmin/PlatformSupport/PlatformAuditor roles; bypass tenant-scoped RBAC/ABAC and access platform endpoints for cross-tenant data

### User Management
- **Full Audit Trail** — Login/logout events, activity logs, registration tracking
- **User Profile** — Self-service profile editing including primary tenant selection (multi-tenant users)

### Fund Registry
- **CRM** — Party (with multi-role `PartyRoleAssignment`), Investor (with extension profiles), and `InvestmentAccount` as the unit of investment activity; Party↔Account and Party↔Party relationships; user-party links; KYC tracking
- **Registry** — Three-tier Product (Scheme) → Fund → FundClass hierarchy; Product holds regulatory identity (ARSN, APIR, ISIN), issuer metadata, and PDS reference; Fund carries BaseCurrency, FundType, and lifecycle status; FundClass holds fee rates, NAV frequency, and class currency; `Fund.ProductId` is optional so standalone funds remain valid
- **Holdings** — Authoritative unit ledger per (InvestmentAccount, FundClass); read-only HTTP; mutated exclusively via integration events
- **Transaction** — Subscription, Redemption, Transfer, and Switch processing; cross-module KYC + class-status validation; `Process(navPrice)` calculates units and triggers Holdings update

### Platform Services
- **Integration Events** — In-process `IIntegrationEventBus` (provider-swappable); module contracts live in `.Abstractions` projects
- **Background Jobs** — Hangfire with fire-and-forget, delayed, and recurring job support
- **Email Notifications** — SendGrid with HTML/plain-text, templated, and batch sending

### Developer Experience
- **793 Tests** — 729 backend (xUnit) + 64 frontend (Vitest) across all layers
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
├── ApiHost/IFX.ApiHost/             # Host application
├── BuildingBlocks/
│   ├── App.Abstractions/            # Shared interfaces (IModuleInstaller, IAppMigrator)
│   └── IFX.BuildingBlocks.Security/ # Cross-cutting security (ICurrentUser, OPA client, ABAC)
├── WebUI/IFX.WebUI/                 # Demo OAuth client (HTML/JS)
├── Modules/
│   ├── Auth/                        # Authentication & authorization module
│   │   ├── Domain/                  # Users, Identity, Authorization subdomains
│   │   ├── Application/             # CQRS handlers
│   │   ├── Infrastructure/          # EF Core, Cognito/Auth0 adapters, OIDC
│   │   ├── Presentation/            # Minimal API endpoints
│   │   └── Composition/             # Module entry point
│   ├── CRM/                         # Party & Investor management
│   │   ├── Abstractions/            # ICrmReader, integration events
│   │   ├── Domain/                  # Party, Investor, PartyInvestorRelationship entities
│   │   ├── Application/             # 14 CQRS handlers, validators, AutoMapper
│   │   ├── Infrastructure/          # CrmDbContext (schema: crm), repositories
│   │   ├── Presentation/            # 14 endpoints (8 Party, 6 Investor)
│   │   └── Composition/             # Module entry point
│   ├── Registry/                    # Product → Fund → FundClass management
│   │   ├── Abstractions/            # IRegistryReader, integration events (incl. Product events)
│   │   ├── Domain/                  # Product, Fund, FundClass entities; ProductType/ProductStatus enums
│   │   ├── Application/             # 16 CQRS handlers (6 Product, 5 Fund, 5 FundClass)
│   │   ├── Infrastructure/          # RegistryDbContext (schema: registry); AddProduct migration
│   │   ├── Presentation/            # 16 endpoints (6 Product, 5 Fund, 5 FundClass nested)
│   │   └── Composition/             # Module entry point
│   ├── Holdings/                    # Unit ledger (read-only HTTP; event-driven writes)
│   │   ├── Abstractions/            # IHoldingsReader, HoldingFrozenEvent
│   │   ├── Domain/                  # Holding entity with ApplySubscription/Redemption/Freeze
│   │   ├── Application/             # 4 queries + TransactionProcessed/ClassStatusChanged handlers
│   │   ├── Infrastructure/          # HoldingsDbContext (schema: holdings)
│   │   ├── Presentation/            # 4 read-only GET endpoints
│   │   └── Composition/             # Module entry point + event handler registration
│   └── Transaction/                 # Subscription/Redemption/Transfer/Switch processing
│       ├── Abstractions/            # ITransactionReader, integration events
│       ├── Domain/                  # Transaction entity state machine (Pending→Processed→Settled)
│       ├── Application/             # 6 commands + 2 queries; cross-module KYC + class validation
│       ├── Infrastructure/          # TransactionDbContext (schema: transaction)
│       ├── Presentation/            # 8 endpoints
│       └── Composition/             # Module entry point
└── Platform/
    ├── Messaging/                   # Integration event bus (IIntegrationEventBus)
    │   ├── Abstractions/            # IIntegrationEvent, IIntegrationEventBus, IIntegrationEventHandler
    │   ├── Infrastructure.InMemory/ # InMemoryIntegrationEventBus (provider-swappable)
    │   └── Composition/             # AddMessaging(), AddIntegrationEventHandler<>()
    ├── BackgroundJobs/              # Hangfire background job service
    │   ├── Abstractions/            # IBackgroundJobService
    │   ├── Infrastructure.Hangfire/ # Hangfire implementation
    │   └── Composition/             # DI registration
    └── Notifications/               # SendGrid email service
        ├── Abstractions/            # IEmailService
        ├── Infrastructure.SendGrid/ # SendGrid implementation
        └── Composition/             # DI registration
tests/                               # 729 backend tests
├── IFX.Modules.Auth.Domain.Tests/       # Domain entity tests (106)
├── IFX.Modules.Auth.Application.Tests/  # Handler + validator tests (225)
├── IFX.Modules.Auth.Infrastructure.Tests/ # Repository + resolver tests (54)
├── IFX.Modules.Auth.Presentation.Tests/ # Authorization class tests (10)
├── IFX.IntegrationTests/               # Permission enforcement + API tests (46)
├── IFX.Platform.BackgroundJobs.Tests/  # Hangfire service tests (11)
├── IFX.Platform.Notifications.Tests/   # Email service tests (17)
├── IFX.Modules.CRM.Domain.Tests/       # CRM domain entity tests
├── IFX.Modules.CRM.Application.Tests/  # CRM handler tests
├── IFX.Modules.Registry.Domain.Tests/  # Registry domain entity tests (Fund, FundClass, Product)
├── IFX.Modules.Registry.Application.Tests/ # Registry handler tests (Product + Fund + FundClass)
├── IFX.Modules.Holdings.Domain.Tests/  # Holdings domain entity tests
├── IFX.Modules.Holdings.Application.Tests/ # Holdings handler tests
├── IFX.Modules.Transaction.Domain.Tests/   # Transaction domain entity tests
└── IFX.Modules.Transaction.Application.Tests/ # Transaction handler tests
src/Frontend/IFX.FrontEnd/src/          # 64 frontend tests (Vitest + RTL + MSW)
├── components/shared/__tests__/        # Chip, Modal, SortableHeader, ProtectedRoute
├── api/__tests__/                      # tokenStorage / apiClient
├── contexts/__tests__/                 # AuthContext
├── pages/__tests__/                    # RoleManagementPage, PermissionManagementPage
└── pages/auth/__tests__/              # CallbackPage, LoginPage
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

# Backend tests (729)
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
