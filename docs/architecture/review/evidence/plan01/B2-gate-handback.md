# Plan 01 B2 Gate handback

Date: 2026-09-08

Result: accepted for Plan 01 synchronous scope

Still open: Plan 02/B3, B4, G03/G05 production-dependent evidence, and Gate Final Closure

## G03 return

- `crm.account-compliance.v1` and `registry.class-subscription-availability.v1` are Active with
  physical provider-owned source, current API/schema snapshots, provider tests, Transaction
  compatibility tests, and approved Change Records.
- Four Readers, fifteen methods, and seven DTOs were removed or internalized. Their 26 catalog
  records are retained as Retired history; the 20 event records remain `LegacyPendingMigration`.
- Source reconciliation and the Phase 7 governance handoff pass. Gate authority remains in the G03
  catalog and generated view; no provider graph was copied into `src/layerguard.json`.

## G05 return

- Real providers validate consumer, version, provenance, tenant scope, and resource tenant before
  data access and create isolated child execution scopes.
- The real Transaction adapter creates a new RequestId, preserves correlation/causation, propagates
  caller cancellation, and fails closed on timeout, unavailable provider, tenant mismatch, or
  invalid protocol state.
- `isApproved` C3 exposure is approved only as a response-lifetime decision with tenant/consumer
  controls and redacted logging. No C4 field is exposed.

## LayerGuard continuity

The pre-catalog-change B2 comparison against immutable B1 reports 103 matched, 0 new, and 13 stale
entries. The stale entries are removed legacy dependency edges, not suppressed findings. Formal B2
contains the remaining 103 entries and is baseline-clean (0 new, 0 stale). The policy hash changed
only because the authoritative G03 catalog/generated projection now records Active contracts and
Retired legacy surfaces. A LayerGuard implementation defect was corrected so G03/G05-bound shared
primitive projects are treated as shared primitives from non-Domain rings; the allowlist remains
Gate-owned and `src/layerguard.json` was not weakened.

## Evidence index

- [`B2-status.json`](B2-status.json)
- [`B2-vs-B1-report.json`](../layerguard/B2-vs-B1-report.json)
- [`B2-report.json`](../layerguard/B2-report.json)
- [`B2-dependency-graph.json`](../layerguard/B2-dependency-graph.json)
- [`G03-B2-guard-report.json`](../gates/G03/G03-B2-guard-report.json)
- [`G05 verification summary`](g05-verification/verification-summary.json) — full solution 1,059 passed, 0 failed
- [Chinese design](../../plan01-contracts-adapters-boundary.zh-CN.md) and
  [English design](../../plan01-contracts-adapters-boundary.en.md)
