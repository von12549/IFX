<!-- Copied/merged guidance for AI coding agents from CLAUDE.md + README.md -->
# Copilot instructions for IFX repository

Purpose: give an AI coding agent the minimal, concrete knowledge to be productive in this codebase.

- Big picture:
  - Modular-monolith with Clean Architecture: host in [src/ApiHost/IFX.ApiHost](src/ApiHost/IFX.ApiHost) and a single Auth module in [src/Modules/Auth](src/Modules/Auth).
  - Layers: Presentation (Minimal APIs) → Application (CQRS + MediatR) → Domain (pure logic) → Infrastructure (EF Core, AWS Cognito).
  - Composition projects implement `IModuleInstaller` for discovery-based wiring (see [src/Modules/Auth/IFX.Modules.Auth.Composition](src/Modules/Auth/IFX.Modules.Auth.Composition)).

- Key patterns to follow and search for:
  - Endpoint mapping: static `Map*Endpoints()` methods; module registration occurs via `IModuleInstaller.MapEndpoints(app)` in `Program.cs`.
  - CQRS: Commands/Queries in `Application` with one handler per request; pipeline behaviors (ValidationBehavior, TransactionBehavior) are used.
  - EF Core: `IfxDbContext` lives in Infrastructure; run migrations from the Infrastructure folder *with* `--startup-project` pointing to ApiHost.
  - Multi-IdP data model: core `User` + `UserIdentity` (IdP-scoped). Primary user lookup uses `(issuer, subject)` — `GetByIssuerAndSubjectAsync(issuer, subject)`.

- Common developer workflows (explicit commands):
  - Build solution: `dotnet build IFX.sln`
  - Run tests: `dotnet test`
  - Run with Docker (recommended): `docker-compose up -d` (root) and `docker-compose logs -f auth-api`
  - Run locally: `cd src/ApiHost/IFX.ApiHost` then `dotnet run`
  - EF Core migrations (must run from Infrastructure project):
    - Add: `cd src/Modules/Auth/IFX.Modules.Auth.Infrastructure`
      `dotnet ef migrations add <Name> --startup-project ../../../ApiHost/IFX.ApiHost`
    - Apply: `dotnet ef database update --startup-project ../../../ApiHost/IFX.ApiHost`

- Project-specific conventions (do not deviate unless asked):
  - Minimal APIs only; prefer adding static mapping methods rather than new controllers.
  - Register services via the module's `AuthModuleInstaller`/`DependencyInjection` helpers in Composition.
  - Validators use FluentValidation and are auto-registered by assembly scanning — add validators in `Application/Validators`.
  - Always preserve the `(issuer, subject)` lookup semantics when touching auth logic or claims handling.

- Important files to reference when implementing changes:
  - Startup / wiring: [src/ApiHost/IFX.ApiHost/Program.cs](src/ApiHost/IFX.ApiHost/Program.cs)
  - Module installer: [src/Modules/Auth/IFX.Modules.Auth.Composition/AuthModuleInstaller.cs](src/Modules/Auth/IFX.Modules.Auth.Composition/AuthModuleInstaller.cs)
  - DbContext & configs: search for `IfxDbContext` in `src/Modules/Auth/IFX.Modules.Auth.Infrastructure`
  - Endpoints: `src/Modules/Auth/IFX.Modules.Auth.Presentation` (MapAuthEndpoints, MapUserEndpoints, etc.)
  - Claims enrichment: `UserRoleClaimsTransformation` in ApiHost (adds DB roles to JWT principal).
  - Cognito wrapper: `CognitoService` in Infrastructure (signin/refresh/signout helpers).
  - App settings: [src/ApiHost/IFX.ApiHost/appsettings.json](src/ApiHost/IFX.ApiHost/appsettings.json)

- Integration and external dependencies:
  - AWS Cognito is the primary IdP; code expects Cognito settings in ApiHost appsettings or env vars (UserPoolId, ClientId, ClientSecret, Region).
  - SQL Server is used (docker-compose spins up a container in the repo). Tokens, login events and activity logs are persisted.

- When changing database models:
  - Add migrations in `IFX.Modules.Auth.Infrastructure` and include `--startup-project` as shown above.
  - Preserve the unique constraint on `(Issuer, Subject)` in `UserIdentities` — it is central to multi-IdP lookup.

- Testing notes for agents:
  - Unit and integration tests use `dotnet test`; test projects live under `tests/`.
  - Many behaviors rely on dependency injection and static endpoint mapping; prefer testing handlers and services directly rather than end-to-end unless adding integration tests.

If any part of this file is unclear or you want more examples (e.g., a short code snippet for adding an endpoint or a migration), tell me which area to expand.
