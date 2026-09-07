# G02 Phase 8 — controlled rollout rehearsal evidence

Date: 2026-09-08

## Result

Phase 8 is complete for the user-approved controlled target: a timestamped database inside the current
Docker SQL Server, with separate ephemeral migration and runtime identities. This closes the G02
implementation rehearsal only. It does not claim that a production rollout occurred; production
execution, approval and evidence remain owned by G04 and Database/Release Operations.

## Completed evidence

- The isolated Docker database executed preflight and dry-run, verified a checksummed COPY_ONLY backup
  with `RESTORE VERIFYONLY`, applied all module migrations, validated the result and proved rerun is
  idempotent.
- A separately built one-shot Migrator image completed validation before the API image was started.
  The API's database-only readiness endpoint returned HTTP 200 before and after a compatible restart;
  no database Down operation was invoked.
- The migration identity executed DDL. The runtime identity completed representative DML and read-only
  validation, while a runtime DDL probe was denied by SQL Server.
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

## Scope boundary

The authoritative status is `G02-phase8-external-evidence-status.json`; the sanitized machine-readable
record is `phase8-docker-rehearsal/rollout-evidence.json`. The controlled target was fresh, so shared
history was recorded as `not-present-fresh`; deletion was neither approved nor performed.

Before production deployment, G04/Release Operations must repeat preflight/dry-run review, restore-point
verification, rollout sequencing, compatibility observation, least-privilege verification and any
shared-history archive decision in the actual target environment. Local approval and evidence do not
carry over as production approval.

## Verification

- Controlled Docker rollout rehearsal: passed on SQL Server 2022.
- Rollout evidence validator: passed.
- `IFX.DatabaseBoundary.Tests`: 90 passed, 0 failed.
- `dotnet build IFX.sln --no-restore`: passed, 0 errors; 15 existing package/nullability/obsolete
  warnings surfaced by the rebuild.
- `dotnet test IFX.sln --no-build --no-restore`: passed, 901 tests.
- G02 deterministic guard: passed; 5 modules, 14 migrations, 0 cross-schema findings and 0 secrets.
- LayerGuard B0.5: `baseline-clean`; 116 matched, 0 new, 0 stale. LayerGuard self-tests: 178 passed.
