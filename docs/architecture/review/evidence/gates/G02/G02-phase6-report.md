# G02 Phase 6 — Expand/Contract and recovery policy evidence

Date: 2026-09-08

## Result

Phase 6 is complete. Schema evolution, partial upgrades, application rollback and exceptional
database restore now have explicit fail-closed rules, review records, CI enforcement and reusable
operator templates.

## Implemented controls

- The five-stage template separates additive Expand, read transition, write transition, resumable
  backfill and Contract. It prevents replacement and removal from being treated as one release.
- The database migration pull-request template requires architecture and database review for drop,
  rename, non-null transition, type/width alteration and large backfill, plus lock/log/storage impact.
- `migration-safety-policy.json` fixes `roll-forward` as the default and disables automatic Down. The
  deterministic guard binds every high-risk migration review record to the migration source hash and
  signals; new unreviewed high-risk source fails CI.
- The five existing `AlterAuditColumnsToDateTimeOffset` migrations are recorded only as
  `pre-gate-baseline`. This is inventory evidence, not a retroactive claim of production approval.
- The recovery runbook classifies not-started/current/advanced-compatible/advanced-incompatible/
  unknown module state, defines ApiHost blocking and safe same-artifact rerun, and covers lock timeout,
  process termination, connection interruption, module failure and post-validation failure.
- Application image rollback must pass the older image's compatibility manifest. Database rollback
  is exceptional, separately scripted and reviewed, rehearsed against a restore, and never implied by
  an image rollback.
- The database upgrade audit template requires manifest/SQL/report hashes, approval references,
  verified restore point, module state, data impact, controlled operator, recovery evidence and next
  release condition without secrets or business rows.

## Verification

- Migration safety policy guard: passed; 5 high-risk baseline migrations, 5 hash-bound records,
  `automaticDownAllowed=false`, default `roll-forward`.
- `IFX.DatabaseBoundary.Tests`: passed, 75 tests, including risk-review coverage, no targeted Down
  execution, stage template completeness, recovery scenarios and audit fields.
- `dotnet build IFX.sln --no-restore`: passed, 0 errors; 15 existing package/code warnings.
- `dotnet test IFX.sln --no-build --no-restore`: passed, 886 tests.
- G02 deterministic guard: passed; 5 modules, 14 migrations, 0 cross-schema findings and 0 secret
  findings.
- LayerGuard B0.5 comparison: `baseline-clean`; 116 matched, 0 new, 0 stale.

No exceptional rollback script was required or executed. The checked-in SQL file is an inert
fail-fast template and cannot run until reviewers replace its unconditional `THROW`.
