# V4 P10.1 C1n — raw reference allow-list and Contracts cycles

Status: `AUTHORIZED IMPLEMENTATION TRANCHE — candidate only`

The C1l executable-rule audit found `RING-REFERENCE` and `CONTRACT-CYCLE`
active but absent from the numbered-rule mapping. Implement both as a
read-only V4 Pre extension candidate. Bind IFX `layerguard.json`, G03 shared
primitives and V3 `ReferenceRules`, `OwnershipRules`, `Ruleset` sources by
hash; use their policy facts, not their runtime code.

For in-scope `src` projects, judge only direct raw `ProjectReference` names
against the configured ring allow-list. An explicitly empty list forbids every
non-exempt reference. Preserve the V3 exceptions for shared primitives and
in-scope targets already rejected by the direction table, so one edge is not
reported twice. Separately, detect cycles among Contracts projects connected
by direct raw references, deduplicating by cycle membership. Missing `src`,
malformed XML, unresolved/escaping/linked project paths and zero relevant
subjects block. Require nonvacuous direct-reference and Contracts-project
coverage, without inventing a minimum violating count.

Test clean, off-list, empty-list, shared-primitive, direction-exemption,
two-/multi-node cycle, zero and unsafe controls, deterministic results and
TargetRoot byte invariance. Exercise a synthetic-only extension against the
verified published 1.1.2 Host. Run isolated IFX package regression, Package
hash, Formal Pre before candidate edits and exact Formal Diff. Do not change
V4 Host, released/installed bytes, PATH-repair files or production Profile.
This tranche does not cover MSBuild-evaluated references or the two injection
rules; C5 and C1o remain blockers for C1 closure.

## Verification record

Formal Pre passed before candidate edits at
`artifacts/guards/p10-ifx-c1n/formal-pre`. Source hashes and IFX/G03 policy
projections, module/config/result schemas, dependency lock and capability
ceiling passed direct checks. Thirteen fixtures cover direct allow/off-list,
empty-list, shared-primitive and direction exemptions, two-/three-node cycles,
missing/malformed/unsafe inputs, zero references, zero Contracts and zero
projects. Policy drift, linked-path, deterministic repeat and TargetRoot
byte-invariance controls passed. The real IFX scan covered 147 direct
references and ten Contracts projects with zero new findings. A synthetic-only
extension composed and receipt-verified against the C1i-verified published
1.1.2 base; Host Pre clean, off-list, cycle and zero-project controls passed.
Evidence: `artifacts/guards/p10-ifx-c1n/test-runs/f290e8de23ee429c93b2ffb787f746db`.
The isolated IFX package positive/negative regression passed at
`artifacts/guards/v3-ifx-package-test-f4e8b12d3c234c55b4aaa664e37f4c41`.
The published 1.1.2 Package check remains `pass` with hash
`922196c12917436b087c9c09361ca3669103992694eb5aa0ca8f2873ecc11a8d`.
No production Profile or final human-reviewed bundle was created.
