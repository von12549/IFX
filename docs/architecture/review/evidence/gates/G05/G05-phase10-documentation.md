# G05 Phase 10 — bilingual architecture documentation

Date: 2026-09-08

## Outcome

The G05 design is published in Chinese and English with the same ten decision IDs and equivalent
PRE-READY meaning. It includes terminology, identifier lifecycles, forbidden substitutions, the
six-class failure matrix, C0-C4 admission matrix, observability/compatibility operations, security
remediation status, and rule-to-owner/code/catalog/test/metric/approval mapping.

Six Mermaid sources cover current and target context architecture, HTTP-to-Contract propagation,
producer-to-Outbox/transport/Inbox/downstream Event propagation, tenant trust selection, and the
failure/retry/quarantine/replay state model. Mermaid CLI 11.17.0 rendered every source to SVG and PNG.
Visual inspection found and corrected a state-edge label parsing defect, then confirmed that all nodes,
lifelines, branches, terminal states, and labels render without missing content. The SVG documents are
the scalable review surface; PNG files provide directly viewable evidence.

Architecture indexes, the prerequisite and master plans, and all three atomic plans link the G05 design
and handoff boundaries. The documentation validator checks all bilingual, rendering, content, index,
backlink, mapping, and PRE-READY invariants.

## Verification

- Documentation validator: passed every Phase 10 check.
- Mermaid sources/rendered triplets: 6/6.
- Bilingual decision parity: 10/10.
- Cumulative G05 Phase 10 guard: passed.
- LayerGuard: 179/179 tests passed with zero new or stale baseline violations.
- Phase 9 unified solution baseline remains 1041/1041 tests and zero build errors; Phase 10 changes
  documentation and verification scripts only.

## Truthful remaining evidence

The documents explicitly retain PRE-READY status. Plan 01/02 real carriers, durable messaging,
LayerGuard 03-A1, production telemetry/audit controls, C3 approvals, production migration execution,
runtime handoff evidence, and final five-party approval are not represented as complete.
