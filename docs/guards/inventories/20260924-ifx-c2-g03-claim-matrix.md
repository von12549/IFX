# IFX C2 — G03 Phase 9 claim and authority matrix

Status: `C2 INCOMPLETE — exact inventory complete; V4 modules missing`

The active Post gate is `v3-specialized-g03`, a base-owned judging gate. Its
dispatcher invokes `Invoke-G03ContractEventGuard.ps1 -Phase 9` over candidate
catalog and target source/docs, while governance input and snapshots are
derived candidate artifacts. C1's provider rules are only adjacent architecture
claims; neither they nor the V3 `governance.json` copy replace Phase 9.

The companion JSON freezes nine detector script hashes, ten authority hashes,
all **15** aggregate Phase 9 checks and **65** distinct catalog error codes
(62 `Add-Error` codes plus `sync-cycle`, `mixed-cycle` and `self-test`). Each
check/code has a destination. The main delivery split is:

| Slice | Active claim families | Required negative and zero controls |
| --- | --- | --- |
| C2b | Catalog schema; owner/backup/consumer; provider graph; protocol lifecycle; field C3/C4 and sensitive-use policy; shared primitives; waiver/exception validity; LayerGuard handoff | Missing/stale/invalid catalog and projection, duplicate/missing identity, owner or consumer, unapproved provider, forbidden field, expired/unwaivable waiver, zero protocol/edge/owner subjects. |
| C2c | Fresh inventory, exact post-migration counts, source/catalog reconciliation, generated-source exclusion, deterministic API/schema snapshots | Missing source, unexpected/omitted surface, wrong reader/event counts, generated contamination, stale or nondeterministic snapshot and zero source subjects. |
| C2d | Bilingual docs, diagrams/local links, legacy disposition/deadline, closeout blocker metadata and readiness state | Missing/broken docs/assets/links, overdue legacy item, blocker without owner/revisit, false `ready-for-approval` or missing status. |
| C2e | Combined direct/dependency Post Stage, authority locks, immutable roots and V3 comparison | Missing dependency, stale evidence, unreviewed waiver, clean/violating/zero aggregate and TargetRoot byte invariance. |

The local V3 Phase 9 replay passed all 15 aggregate checks; catalog validation
reported zero errors and all 18 built-in mutation self-tests passed. The
checkpoint covers 8 modules, 6 protocols, 46 legacy public-surface entries,
200 fields (11 C3), 8 field exceptions, 6 shared primitives and 9 graph edges.
This **does not** mean G03 business closeout is approved: the closeout audit
passed with `closureStatus=pre-ready`, `readyForClosure=false` and three
recorded blockers: `protocols-not-active`, `behavior-tests-pending` and
`closure-approvals-pending`. Preserve this distinction in V4 evidence.

Evidence is under `artifacts/guards/p10-ifx-c2a/v3-phase9/`. The JSON matrix
records exact hashes and checkpoint counts. C2b–C2e remain separate bounded
child Plans requiring Formal Pre before executable edits. The current C1
candidate set and PATH-repair files are unchanged by this inventory.
