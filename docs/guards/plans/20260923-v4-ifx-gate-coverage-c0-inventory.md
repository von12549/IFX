# V4 P10.1 C0 — exact IFX gate and authority inventory

Status: `C0 SOURCE INVENTORY COMPLETE — no V4 runtime gate accepted`

Predecessor: `20260923-v4-ifx-gate-coverage-program`. The user asked to begin
the remaining-gate program. This checkpoint is a read-only audit of active
V3_ifx declarations plus documentation of the V4 destination/gap matrix. It
does not implement detectors, alter a bundle, publish a patch, compose an
installation or activate any repository controls.

## Authority boundary and output

Freeze the current Git source commit, the V3_ifx guard-system/profile layout,
command and authority registries, six Stage manifests, Post policy and baseline,
eleven rule files, and historical-integrity manifest. Enumerate every declared
gate ID from Stage manifests, every domain authority from the authority registry,
its role/path/SHA-256, four projections and eight G04 bindings. Record command
IDs and toolchain requirements, architecture claim/detector families and known
cross-coverage, waiver/exception states and the difference between direct
P10.1 runtime gates and Diff/CI governance work reserved for P10.3.

The machine-readable inventory and human-readable analysis must reconcile the
eight anchors in the 0.2.0 bundle draft with the full manifest graph. Every
gate gets an explicit destination or blocking gap; no V3 execution script is
silently imported into V4. If the active manifest graph references an absent
file or an unclassified gate, this checkpoint fails instead of assuming it is
out of scope. Update the parent program's workstream table for Plan04,
Database, Quality and Historical Integrity discovered during inventory.

## Validation and handoff

Pass Formal Pre before editing the parent program or inventory files, then
schema/identity checks, exact path/hash/count reconciliation, isolated
`ifx-package-test`, unchanged V4 Package hash and exact Formal Diff. C0 closes
only the source/obligation inventory. Its final row set drives an exact child
Plan for the first bounded C1 implementation tranche, whose paths, module
capabilities and fixtures are not authorized by this inventory Plan.

Formal Pre passed before the inventory and parent-program edits. The source
reconciliation checked all 13 declared gate IDs and trust types, 36 domain
authorities, four projections, eight bindings, 11 rule file hashes and
contracts, nine IFX policy rule bindings and 19 registered commands against
the frozen source commit. The isolated IFX package test passed its positive
and negative cases. Local V4 Package validation returned the published
1.1.2 hash `922196c12917436b087c9c09361ca3669103992694eb5aa0ca8f2873ecc11a8d`.
Exact Formal Diff over the declared five paths passed at
`artifacts/guards/p10-ifx-c0/formal-diff/summary-diff.json`; its generated
.NET Stage test passed one of one. This establishes C0 documentation scope,
not acceptance of a real V4 IFX gate or extension bundle.
