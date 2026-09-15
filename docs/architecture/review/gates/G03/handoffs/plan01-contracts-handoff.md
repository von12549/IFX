# G03 -> Plan 01 Contracts / Ports / Adapters handoff

> Plan 06 location update: [implementation handback](../../../evidence/plan06/P06-implementation-handback.md) records provider Infrastructure inbound adapters, Application-owned use cases and producer V1 mappers. G03 source reconciliation and Phase 9 passed, and regenerated public API/serialization snapshots match the authoritative files. Protocol identities and lifecycle are unchanged; closure remains `pre-ready`. The B2 acceptance below is historical.

## Accountability and revisit

- Recorded accountable owner: `xiaolong-feng` / repository handle `@von12549`, acting for the CRM,
  Registry, Transaction, Holdings, and repository-maintainer roles recorded in the catalog.
- Delivery owner: Plan 01 implementer, approved by the recorded accountable owner. Junxi /
  `@jimkeecn` is the authorized backup owner recorded by G03.
- Revisit trigger: the first PR that creates a provider `*.Contracts.V1` project or replaces a
  legacy Reader/DTO. Revisit completed at B2 when both synchronous identities became Active.

## Authoritative inputs

- [`contract-event-catalog.yaml`](../contract-event-catalog.yaml) is the only ownership, identity,
  field-classification, lifecycle, and disposition source.
- [`G03-sync-api-snapshot.json`](../snapshots/G03-sync-api-snapshot.json) is the current source-backed
  Active shape baseline.
- [`compatibility-policy.md`](../compatibility-policy.md),
  [`shared-contract-primitives.md`](../shared-contract-primitives.md), and the Change Record template
  define admission and migration mechanics.

Plan 01 owns 4 Readers, 15 Reader methods, and 7 DTOs. The catalog dispositions are: Readers = 2
Replace/2 Internalize; methods = 2 Replace/10 Internalize/3 Remove; DTOs = 7 Internalize. The two
admitted candidates are `crm.account-compliance.v1` and
`registry.class-subscription-availability.v1`, both CRM/Registry -> Transaction and both Active at B2.

## Required implementation and returned evidence

1. Create provider-owned, BCL-only `Contracts.V1` surfaces with exact stable identities and field
   purpose/classification from the catalog; do not copy the general Reader surface.
2. Create Transaction-owned Ports and outer Integration Adapters. Transaction Application must not
   reference foreign Contracts directly; Composition owns binding.
3. Internalize/remove every remaining Reader method and DTO exactly as cataloged by 2026-12-01.
4. Add provider behavior tests for tenant, authorization, NotFound, Denied, Unavailable,
   cancellation, freshness, and documented failure semantics.
5. Add consumer tests for Adapter mapping, optional/unknown fields and values, fallback, and the
   supported prior version. Regenerate the real public API snapshot and source reconciliation.
6. Submit Change Records and Provider + Transaction Consumer approvals. Only then request Active
   promotion and G03 Phase 6/9 re-evaluation.

Do not return a green build alone as compatibility evidence, and do not mark G03 Active while a
consumer still calls legacy Abstractions.

## B2 return accepted 2026-09-08

All 26 Reader/method/DTO records are Retired with source reconciliation; the two capability
contracts are source-backed and Active. Provider and consumer compatibility tests, current API
snapshots, G03 validation, LayerGuard B2 comparison, and the complete handback are indexed in
[`B2-status.json`](../../../evidence/plan01/B2-status.json) and
[`B2-gate-handback.md`](../../../evidence/plan01/B2-gate-handback.md). Event protocols remain
Proposed and are owned by Plan 02/B3.
