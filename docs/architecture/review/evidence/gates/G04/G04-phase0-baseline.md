# G04 Phase 0 deployment/runtime baseline

Date: 2026-09-08  
Branch: `feature/architecture-boundary-implementation`  
Scope: evidence captured before G04 runtime implementation

## Preconditions and repository state

- The working tree was clean at the start of G04 and the requested branch was already checked out.
- G01 is technically complete but awaits E2/E4 evidence and final sign-off.
- G02 is PRE-READY and awaits E2/E4, G04 production orchestration evidence and final sign-off.
- G03 is PRE-READY; the independent backup-owner decision, Plans 01/02 behavior migration, Plan 03 L5.1 binding and final approval remain open. These do not prevent G04 implementation.
- G05 is decision-approved but not implemented. G04 therefore records Gate 05 integration points without claiming its context or sensitive-data controls are complete.
- Plan 02 E3/E6 and Plan 03 L5.1 are downstream owners. This baseline and later G04 reference conformance must not be presented as their real Dispatcher, backlog, replay or policy-binding evidence.

## Current executable and deployment inventory

The reproducible inventory is in `G04-runtime-inventory.json`. The business process is `IFX.ApiHost`, which loads Auth, CRM, Registry, Holdings and Transaction together. The frontend and Database Migrator are separate application artifacts. SQL Server, `sqlserver-init`, OPA, Cognito and SendGrid have independent infrastructure/provider lifecycles.

The terms are deliberately separated:

- source module: a bounded source tree and ownership unit;
- assembly: a compiled project output;
- process: an executing host;
- artifact: an immutable image/package intended for deployment;
- release: a compatible set of artifacts and metadata;
- deployment boundary: a unit with its own rollout, scaling, readiness and shutdown lifecycle.

Five source modules and many assemblies still form one business release boundary. Separate containers for SQL, OPA, frontend and migration do not make those business modules microservices.

## Current startup order and embedded runtime

`Program.cs` registers the five modules, then Messaging, BackgroundJobs and Notifications, builds the host, installs middleware/dashboard/health, and finally enumerates `IModuleInstaller` to map endpoints. Database migration has already moved to the separate Gate 02 Migrator; Compose orders SQL health → init completion → Migrator completion → API. Module endpoint order still relies on DI enumeration.

Hangfire client and server are registered together by `AddBackgroundJobs`, so every API replica also starts a server. A fixed `auth-api-worker` default can identify multiple replicas ambiguously. There is no custom application `IHostedService`/`BackgroundService`, Outbox Dispatcher, transport consumer, recurring-definition authority, lease loop or explicit shutdown coordinator. In-memory post-commit messaging is scoped execution, not durable transport.

## Current probes and false-positive scenarios

`/health` and `/health/ready` both select every registered check. SQL, Cognito and schema compatibility are mixed into the aggregate; `/health/database` is the only specialized endpoint. There is no dependency-free liveness, monotonic startup probe, role-aware readiness or protected/sanitized details endpoint.

Consequently, a Cognito outage can make the whole host unready even when safe reads are possible; conversely, a silently absent future Dispatcher cannot affect readiness. Network checks in the aggregate can also create probe amplification. Ordinary health output currently exposes check descriptions and tags without a G05-approved details policy.

## Current scaling, shutdown and failure baseline

Compose declares no replicas, stop signal or grace period. HTTP scaling therefore also multiplies Hangfire WorkerCount, while the fixed server name reduces diagnostic clarity. Shutdown depends on framework defaults; no component first marks NotReady, blocks new claims/schedules, drains bounded in-flight work or records a stable reason. There is no durable Dispatcher state to validate forced-kill takeover yet.

The baseline does not claim any target capability exists. The missing Runtime Role, manifest validation, lease conformance, backlog/backpressure, separated probes and drain semantics are the explicit input to Phases 1–12.

## Reproduction

```powershell
./scripts/Invoke-G04DeploymentRuntimeInventory.ps1
./scripts/Invoke-G04DeploymentRuntimeGuard.ps1 -Phase 0
./scripts/Invoke-LayerGuard.ps1 -SkipTests -ReportPath docs/architecture/review/evidence/gates/G04/G04-phase0-layerguard-report.json
dotnet build IFX.sln --no-restore
dotnet test IFX.sln --no-build --no-restore
```

All four checks passed on 2026-09-08. The solution build completed with 0 errors and 20 pre-existing warnings; the solution test run passed 904 tests with 0 failures and 0 skips. The warnings are the already-present AWSSDK version fallback, vulnerable-package advisories, nullable warnings and obsolete login endpoint warning; Phase 0 introduced no source compilation warnings.
