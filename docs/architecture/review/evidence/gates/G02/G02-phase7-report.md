# G02 Phase 7 — SQL Server migration matrix evidence

Date: 2026-09-08

## Result

Phase 7 is complete. A SQL Server 2022 Testcontainers fixture now runs every migration scenario
against a disposable database and exercises the same `DatabaseMigratorRunner`, EF migrations,
history bootstrap, Auth adoption, application lock and validation code used by the one-shot job.

## Matrix coverage

- Fresh migration applies all 14 migrations in fixed module order, creates all five schemas and
  owned histories, has no cross-schema foreign keys, and applies nothing on rerun.
- Shared `dbo.__EFMigrationsHistory` is copied exactly, including ProductVersion, into module-owned
  histories; the source rows remain byte-for-byte equivalent and are not deleted or rewritten.
- Auth canonical, exact 14-ID pre-squash and incorrect-alias histories normalize to the canonical
  chain. Partial legacy history, partial schema and a missing baseline index fail closed without
  stamping or rewriting history.
- A complete historyless Auth schema is blocked until explicit adoption is supplied; a matching
  fingerprint is then stamped and upgraded to latest.
- Previous-release schemas preserve a CRM sentinel row while applying the latest audit-column
  migration, and the second run is idempotent.
- Two migrators serialize on the database application lock: one applies all 14 migrations and the
  other applies zero. A held lock produces the configured explicit timeout.
- Injected CRM failure records `module:CRM`, prevents later module execution, and a normal rerun
  completes by roll-forward.
- The migration identity creates DDL. A separately provisioned runtime login can run DML and
  read-only validation across owned schemas, has no ALTER permission, and cannot create a table.

The live matrix exposed and closed three defects that deterministic tests could not reveal: leading
underscores were rejected in valid EF history identifiers; the Auth fingerprint included a virtual
same-table owned-type foreign key and unnormalized filtered-index SQL; and fingerprint metadata
included the history table's primary key.

## E2/E4 and CI handoff

`G02SqlServerAssertions` provides reusable exact-history and no-cross-schema-FK assertions for the
Plan 02 E2/E4 Outbox/Inbox migrations. Those later migrations must append their own fresh/upgrade
matrix evidence before Gate 02 can claim the final messaging-table condition.

The database workflow now builds the solution, rejects pending model changes for all five contexts,
generates and safety-checks SQL artifacts, runs deterministic boundary tests, and runs the live SQL
Server matrix as a separately named CI step.

## Verification

- SQL Server migration matrix: 12 passed, 0 failed.
- `IFX.DatabaseBoundary.Tests`: 87 passed, 0 failed.
- Five-context `dotnet ef migrations has-pending-model-changes`: no changes for every context.
- `dotnet build IFX.sln --no-restore`: passed, 0 errors; 15 existing warnings.
- `dotnet test IFX.sln --no-build --no-restore`: passed, 898 tests.
- G02 deterministic guard: passed; 5 modules, 14 migrations, 0 cross-schema findings and 0 secrets.
- LayerGuard B0.5: `baseline-clean`; 116 matched, 0 new, 0 stale. LayerGuard self-tests: 178 passed.
