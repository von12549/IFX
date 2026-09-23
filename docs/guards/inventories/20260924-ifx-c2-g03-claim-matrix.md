# IFX C2 — G03 Phase 9 claim and authority matrix

Status: `C2 INCOMPLETE — C2b1/C2b2 catalog candidates validated; C2c–C2e pending`

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

## C2b1 checkpoint

The bounded `ifx-g03-governance-core` Post candidate now checks owner and
backup/consumer references, provider and adapter graph including cycles,
shared-primitives and BCL-only contract policy, waiver validity, and exact
catalog-to-LayerGuard governance projection. Four distinct Host rule IDs map
to four coverage claims. A current catalog with zero waiver entries is valid
because the 90-day/unwaivable policy is checked independently; empty owners,
protocols or graph edges fail. The candidate passed 20 fixtures, real IFX
input, synthetic published-Host Post, source/authority hash checks and
TargetRoot byte invariance. It is not a production Profile or complete G03
gate. C2b2 must still cover the remaining catalog field, sensitive-use,
protocol-lifecycle/admission, public-surface and change-record predicates;
C2c–C2e remain as assigned above. C1 final closure still waits for C5.

## C2b2 checkpoint

The complementary `ifx-g03-catalog-semantics` Post candidate checks the
remaining catalog lifecycle/admission, C3/C4 field and sensitive-use,
historical public-surface, approval and change-record predicates. Its four
Host rules and claims are separate from C2b1's four rules and claims. The
two candidates represent 62 of the 63 C2b catalog error codes; V3's
`self-test` result is covered by the V4 negative fixture suite. C2b2 passed
46 fixtures, real IFX and synthetic published-Host Post, source hash checks
and TargetRoot byte invariance. These are candidate-level results only:
the C2e combined Stage and production Profile have not been accepted.
Source-field reconciliation and snapshots remain C2c; documentation and
closeout remain C2d. C1 final closure still waits for C5.
