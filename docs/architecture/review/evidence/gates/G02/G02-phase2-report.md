# G02 Phase 2 — module migration history evidence

Date: 2026-09-07

## Result

Phase 2 is complete at the repository implementation boundary. Every module DbContext targets
`<module>.__EFMigrationsHistory`, and the shared-history transition is represented by a dry-run
plan and a SQL Server executor that fails closed before committing inconsistent state.

## Implemented controls

- Auth, CRM, Registry, Holdings, and Transaction configure EF Core's history repository with the
  module schema and the canonical `__EFMigrationsHistory` table name.
- `EfModuleMigrationCatalog` derives migration ownership from the active EF migration assembly and
  derives required tables from the design-time relational model. The bootstrap does not use a
  handwritten global migration-ID list.
- `HistoryBootstrapPlanner` classifies fresh, current shared-history, already bootstrapped,
  explicit-adoption-required, and invalid states before any write. Its module result includes the
  exact copied rows and expected pending migration IDs.
- Unknown or duplicate migration IDs, duplicate module/schema/order ownership, malformed or empty
  fingerprints, foreign target-history rows, partial schemas, missing schemas behind claimed
  history, and conflicting `ProductVersion` values fail closed.
- `SqlServerHistoryBootstrapper` creates EF-compatible history tables and copies rows with their
  original `ProductVersion`. All writes and post-validation run in one database transaction.
- Apply mode obtains an exclusive transaction-owned `sp_getapplock` on
  `IFX.DatabaseMigration`, with a 60-second default timeout. Lock failure aborts the operation.
- Dry-run reads metadata and returns the plan without opening a transaction or issuing DDL/DML.
- Apply mode rereads database metadata inside the transaction and commits only when the second
  plan is valid and contains no remaining bootstrap changes.
- The legacy `dbo.__EFMigrationsHistory` is only queried. The implementation contains no delete,
  update, rename, or drop path for the shared table.
- Repeated planning after target histories contain the copied rows is classified
  `AlreadyBootstrapped` with no changes.

## Verification

- `dotnet build IFX.sln --no-restore`: passed, 0 errors; 14 pre-existing warnings.
- `dotnet test IFX.sln --no-build --no-restore`: passed, 851 tests.
- `IFX.DatabaseBoundary.Tests`: passed, 40 tests. Coverage includes all five EF history targets,
  assembly/model catalog generation, fresh/shared/rerun classifications, pending IDs, unknown and
  duplicate IDs, foreign rows, partial fingerprints, explicit adoption, and ProductVersion conflict.
- `dotnet ef migrations has-pending-model-changes` for all five DbContexts under the Testing
  environment: no model changes.
- G02 deterministic inventory guard: passed; 5 modules, 14 migrations, 0 schema violations, and
  0 secret findings.
- LayerGuard B0.5 comparison: `baseline-clean`; 116 matched, 0 new, 0 stale.

## Deferred live-database proof

Phase 7 owns the SQL Server 2022 Testcontainers matrix. It will execute the Phase 2 executor against
fresh and shared-history databases and will inject lock contention and transactional failures. This
deferral is explicit test staging, not a claim that a production database has been inspected or
modified.
