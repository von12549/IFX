# V4 P10.1 C1l — executable V3 architecture rule closure audit

Status: `AUTHORIZED AUDIT CHECKPOINT — no runtime gate accepted`

C1a mapped the nine IFX `ruleRefs` and eleven numbered rule files, while
C1b–C1k implemented bounded candidate slices. Before C1 can close, compare
the actual V3 `Analyzer` invocation set, effective IFX policy fields and CLI
blocking behavior against the candidate rule plans. A numbered-rule binding
is not a complete inventory of every executable rule: unbound violations can
still contribute to `ViolationCount` and block `check`.

Create a residual runtime-rule inventory with explicit active/inactive
classification, source predicate, policy fact, current V4 destination and
missing fixture/evidence. Check at least direct allow-list references,
injection name/origin, Contracts cycles, forbidden-reference and required-ring
branches. Distinguish source-only work that can start as a later C1 tranche
from compiled/evaluated evidence requiring C5. Do not claim C1 complete,
quietly retire a V3 rule or change a policy binding.

Formal Pre precedes the inventory edit. Validate source hashes and policy
projections, isolated IFX package regression, unchanged published Package
identity and exact Formal Diff over this three-path documentation checkpoint.
The PATH-repair files, published base and production bundle remain untouched.

## Verification record

Formal Pre passed at `artifacts/guards/p10-ifx-c1l/formal-pre` before the
inventory was written. The pinned Analyzer, CLI and IFX policy hashes were
rechecked. The audit identified four still-active, unimplemented executable
rule families: `RING-REFERENCE`, `FORBIDDEN-DEPENDENCY`,
`FORBIDDEN-DEPENDENCY-ORIGIN` and `CONTRACT-CYCLE`. It also classified
`FORBIDDEN-REFERENCE` and `RING-MISSING` as inactive under the current
policy, rather than silently claiming them. The isolated IFX package positive
and negative regression passed with evidence
`artifacts/guards/v3-ifx-package-test-c17b65217b69437ba885e94c1a1f587a`.
This is a scope correction and handoff, not C1 completion.
