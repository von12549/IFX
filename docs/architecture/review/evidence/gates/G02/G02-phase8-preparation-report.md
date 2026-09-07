# G02 Phase 8 — rollout preparation evidence

Date: 2026-09-08

## Result

Repository preparation and the recoverable non-production rehearsal are complete. Phase 8 itself is
not complete because no production target, controlled connection, restore-point record, deployed job
or compatibility-window evidence was supplied. G02-8.2 through G02-8.7 remain explicitly open.

## Completed preparation

- SQL Server 2022 Testcontainers executes fresh preflight, verifies a checksummed COPY_ONLY backup
  with `RESTORE VERIFYONLY`, applies all module migrations, validates the result and proves rerun is
  idempotent.
- The obsolete `IAppMigrator` contract, five DI registrations and five module runtime migrator
  implementations were removed. ApiHost no longer exposes a module-owned `Database.MigrateAsync`
  entry point; only the one-shot DatabaseMigrator retains DDL execution.
- `database-rollout-evidence-template.json` covers approvals, immutable hashes, production preflight
  review, restore verification, apply/validate ordering, compatibility observation, runtime
  permissions and shared-history archival.
- `Test-G02DatabaseRolloutEvidence.ps1` rejects placeholders, missing references, malformed hashes,
  incomplete approvals/controls, failed validation, enabled history deletion and invalid timestamps.
- The production runbook assigns Database/Release Operations ownership and forbids committing
  connection strings, passwords or business rows.

## External closure boundary

The authoritative status is `G02-phase8-external-evidence-status.json`. The remaining controls require
an explicitly named environment and controlled operators. Testcontainers results demonstrate the
mechanism but cannot substitute for production classification, backup, deployment, observation,
least-privilege and archive records.

To close Phase 8, complete a sanitized copy of the rollout template in the controlled evidence
system, validate it with the repository script, and provide the immutable reference plus the three
approval references for review.

## Verification

- Recoverable non-production rollout rehearsal: passed on SQL Server 2022.
- `IFX.DatabaseBoundary.Tests`: 90 passed, 0 failed.
- `dotnet build IFX.sln --no-restore`: passed, 0 errors; 20 existing package/nullability/obsolete
  warnings surfaced by the rebuild.
- `dotnet test IFX.sln --no-build --no-restore`: passed, 901 tests.
- G02 deterministic guard: passed; 5 modules, 14 migrations, 0 cross-schema findings and 0 secrets.
- LayerGuard B0.5: `baseline-clean`; 116 matched, 0 new, 0 stale. LayerGuard self-tests: 178 passed.
