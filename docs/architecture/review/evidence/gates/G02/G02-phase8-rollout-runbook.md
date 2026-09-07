# G02 Phase 8 production rollout evidence runbook

Date: 2026-09-08

This runbook completes the environment-owned portion of Phase 8. It does not authorize access to a
production database and it does not treat repository or Testcontainers results as production
evidence. Database Operations owns the production connection, backup, permission and observation
records; secrets and business rows must not be copied into the repository.

## 1. Freeze inputs

Record the release, change ticket and architecture/database/operations approvals. Verify the
immutable migration, release and artifact manifest hashes from the CI bundle. Use this same bundle
for preflight, apply and validate.

## 2. Production dry-run and review

Run the one-shot job with the migration identity and archive the JSON report outside the repository:

```powershell
./scripts/Invoke-DatabaseMigrator.ps1 -Mode preflight -ReportPath <controlled-preflight-report>
./scripts/Invoke-DatabaseMigrator.ps1 -Mode dry-run -ReportPath <controlled-dry-run-report>
```

Database Operations must review classification, exact shared-to-module history mapping, Auth
fingerprint/adoption status, pending MigrationIds and the absence of unknown/partial state. Do not
continue on a failed or unexpected classification.

## 3. Restore point and one-shot execution

Create the approved backup/snapshot, execute a restore verification, and record both references.
Then run `apply`; a non-zero exit blocks API rollout. Run `validate` with the same artifact before
starting any new API instance. Archive report hashes and the controlled job identity.

## 4. Compatibility observation

Observe the approved window across migration status, read-only readiness, representative business
reads/writes, Worker-before-API ordering, and the application rollback procedure. A rollback test may
use a controlled compatible image; it must not invoke database Down. Record start/end times and
immutable smoke/rollback evidence.

## 5. Permission and history closure

Verify the runtime identity can perform required DML and readiness reads but cannot ALTER/CONTROL
module schemas. Confirm the removed `IAppMigrator` surface is absent from the deployed image. Retain
`dbo.__EFMigrationsHistory` as archived/read-only with unchanged rows; deletion requires a separate
future approval and is not part of first Gate closure.

## 6. Validate evidence

Copy `deployment/database-rollout-evidence-template.json` to the controlled evidence system, replace
every placeholder, set each control only after evidence exists, then run:

```powershell
./scripts/Test-G02DatabaseRolloutEvidence.ps1 -EvidencePath <sanitized-local-evidence-json>
```

Only a passing validator plus the referenced external records may close G02-8.2 through G02-8.7.
