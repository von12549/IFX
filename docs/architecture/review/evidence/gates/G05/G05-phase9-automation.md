# G05 Phase 9 — unified repository verification

Date: 2026-09-08

## Outcome

`scripts/Invoke-G05Verification.ps1` is the single local and CI entry point for the G05 repository
boundary. It composes the existing G03 catalog/security validator, database migration safety check,
cumulative G05 guard and LayerGuard, then builds and tests the solution. It emits machine-readable
reports, TRX results and one hash-linked summary under `artifacts/g05` by default.

The G03 validator remains the sole field-policy authority. Phase 9 extends that validator to reject
expired C3 field exceptions and adds a mutation self-test for the rule; it does not introduce a second
field catalog or semantic validator. LayerGuard remains responsible for static project, dependency,
framework and declaration boundaries.

## Verification

The unified entry point passed and emitted hash-linked reports plus TRX evidence under `artifacts/g05`:

- G03 catalog/security validation passed with all 13 mutation self-tests, including expired C3
  exception, C4 exposure, missing classification and expired/unwaivable waiver failures.
- Migration safety passed for 5 modules, 46 entities and 15 migrations with zero schema violations.
- The cumulative G05 Phase 9 guard passed.
- LayerGuard passed 179/179 tests with zero new or stale baseline violations.
- The solution build completed with zero errors and the existing 20 warning instances.
- The solution passed 1041/1041 tests with zero skipped, including 99 SQL Server migration cases.

The committed `G05-phase9-verification-summary.json` records the exact run and report hashes. No
production or real-carrier claim is inferred from repository automation.

## Truthful boundary

The CI workflow runs exactly the same script as local verification and uploads `artifacts/g05` even on
failure. This phase verifies repository policy and fake-carrier/runtime tests only. Plan 01/02 real
carrier evidence, LayerGuard 03-A1 direct policy binding, production telemetry controls and approvals
remain Gate-close dependencies.
