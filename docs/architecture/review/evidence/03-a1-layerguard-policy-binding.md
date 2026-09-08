# 03-A1 LayerGuard Gate Policy Binding

Date: 2026-09-08
Status: **LG-POLICY-READY — B1 frozen; B2/B3/B4 remain open**
Delivery owner: `@von12549`
Accepting party: Junxi (`@jimkeecn`)

## Bound authorities

LayerGuard `0.4.0-a1` directly loads and fail-closed validates:

- G03 generated governance input and its sole catalog, including projection reconciliation,
  ownership/backup ownership, four provider-consumer edges, shared primitives and waiver policy;
- G04 release runtime manifest, all eight manifest-bound artifacts and hashes, the shared host
  artifact, `api/worker/all` roles and RuntimeHost → Composition-only static boundary;
- G05 Context/Messaging project identities, their BCL-only dependency policy and forbidden
  framework/runtime categories.

The active report records 12 binding rows because G03 includes the source catalog and G04 expands
its eight bound artifacts. `src/layerguard.json` contains physical role patterns and rule mappings,
but does not contain a copied provider graph or shared primitive ownership table.

## Formal B1

| Field | Result |
| --- | --- |
| Tool version | `0.4.0-a1` |
| Verdict | `baseline-clean` |
| Historical findings | 116 |
| Real from/to dependency clusters | 44 |
| Baseline match | 116 matched / 0 new / 0 stale |
| Gate bindings | 12 |
| Waiver maximum | 90 days |
| Baseline expiry | 2026-12-07 |
| Delivery owner | `@von12549` |

The report's composite policy hash covers the target LayerGuard configuration, G03 generated view
and catalog, the G04 runtime manifest and every bound artifact, and the G05 context policy. Any
semantic input change invalidates B1 until it is explicitly reviewed and regenerated. Findings are
grouped by the real `fromProject`/`toProject` edge; individual line findings remain available for
implementation work.

Evidence:

- [`layerguard/B1-report.json`](layerguard/B1-report.json)
- [`layerguard/B1-dependency-graph.json`](layerguard/B1-dependency-graph.json)
- [`03-a1-layerguard-policy-binding-status.json`](03-a1-layerguard-policy-binding-status.json)
- [`03-a1-integration-verification.json`](03-a1-integration-verification.json)
- [`mcp/LayerGuard/baselines/b1.json`](../../../../mcp/LayerGuard/baselines/b1.json)
- [`../../gates/G03/generated/layerguard-governance-input.json`](../gates/G03/generated/layerguard-governance-input.json)

## Fail-closed proof

The 188-test LayerGuard suite contains positive and negative checks for production binding, G03 catalog hash
and projection drift, unknown G03 roles, G04 artifact hash drift, G05 BCL-only drift, policy hash
drift, expiry beyond the Gate maximum, and unwaivable rules. Existing baseline tests also reject
expired entries, removed/stale findings and new fingerprints. CI first runs G03 Phase 7
reconciliation, then the complete tool suite and B1 repository scan.

The final repository regression passed 188/188 LayerGuard tests, 1041/1041 solution tests and a
solution build with zero errors. Twenty known package, nullability and obsolete-endpoint warnings
remain visible and are not claimed as 03-A1 success.

## Explicitly not checked

LayerGuard does not claim field classification, purpose/consumer/retention approval, runtime values,
tenant membership, trace validity, EventId preservation, redaction output, transport delivery,
idempotency or replay behavior. Those remain owned by G03/G05 catalog/schema/security/runtime tests
and must be returned by Plans 01/02 before Gate Final Closure.

## Next control points

- Plan 01 may start and must return B2 under the same target semantics.
- Plan 02 may start and must return B3 under the same target semantics.
- Plan 03 Phase 6–8 remains open; strict zero-unwaived-debt mode and B4 are not claimed.
