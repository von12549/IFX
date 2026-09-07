# G02 Phase 5 — production DDL removal and deployment orchestration evidence

Date: 2026-09-08

## Result

Phase 5 is complete. ApiHost no longer executes module migrators during startup; database change is
an immutable one-shot deployment step, while API readiness performs only release-bound history
reads.

## Implemented controls

- Removed the `GetServices<IAppMigrator>()` / `MigrateAsync` startup block from ApiHost. Integration
  tests no longer need to remove migrators to keep startup from changing a database.
- Added a release schema manifest containing the exact required migration catalog, per-module
  schema/history/runtime connection key, catalog hash, and explicit compatible-additional IDs.
- Added `DatabaseSchemaCompatibilityHealthCheck`. It reads each module-owned history table, requires
  the release catalog, accepts only allowlisted Expand IDs, and fails closed for missing, duplicate,
  unknown, unreachable, or malformed state without returning SQL/connection details.
- Added `scripts` mode and a deterministic artifact command to create five ordered EF idempotent SQL
  scripts, copied manifests, and a SHA-256 artifact manifest. CI publishes these beside the one-shot
  executable for the same commit.
- Updated local and NAS Compose to order SQL health → init success → Migrator success → API. The
  one-shot services have no restart loop, so migration failure blocks the new API.
- Split migration and runtime database configuration surfaces. Production DDL/DML grants remain a
  Database Operations evidence item; local defaults may intentionally resolve both to the developer
  SQL administrator account.
- Added the operator sequence and failure/compatibility policy in
  `G02-phase5-deployment-runbook.md`, including Gate 04's consumer-first Worker → API handoff.

## Verification

- Database migration artifact generation: passed; five idempotent scripts use their module schema
  history tables and the artifact manifest contains a SHA-256 for each script.
- `docker compose config --quiet` for repository and NAS definitions: passed.
- `IFX.DatabaseBoundary.Tests`: passed, 72 tests, including release/catalog consistency, required,
  allowlisted-newer, unknown-newer and missing migration compatibility, no ApiHost DDL startup path,
  Compose ordering, identity separation, and explicit local/CI command checks.
- ApiHost build: passed and its output contains `release-manifest.json`.
- `dotnet build IFX.sln --no-restore`: passed, 0 errors; 14 existing package warnings.
- `dotnet test IFX.sln --no-build --no-restore`: passed, 883 tests.
- G02 deterministic guard: passed; 5 modules, 46 entities, 40 tables, 14 migrations, 0
  cross-schema findings, and 0 secret findings.
- LayerGuard B0.5 comparison: `baseline-clean`; 116 matched, 0 new, 0 stale.

No production identity grants, backup, migration, or rollout are claimed. Those environment-specific
approvals and observations remain Phase 8 evidence.
