# V4 P10.1 C2a — exact G03 Phase 9 claim inventory

Status: `AUTHORIZED AUDIT CHECKPOINT — C2 module not yet accepted`

The C0 inventory lists `v3-specialized-g03` as missing in V4, but the gate is
not equivalent to its exported `governance.json` projection. The V3 Post
dispatcher invokes `Invoke-G03ContractEventGuard.ps1 -Phase 9`; Phase 9 runs
inventory, catalog self-tests, source reconciliation, deterministic snapshots,
LayerGuard handoff, documentation and closeout readiness. Catalogue validation
also contains many independently blocking error codes, including waivers and
field exceptions. Freeze the exact source and authority hashes and map each
active aggregate check and catalog error code to a V4 destination before any
module is implemented.

Create a machine-readable matrix and a concise human review. Distinguish
head-candidate catalog/target facts from derived projections and base-owned
judging code. Identify freshness, zero-subject, negative-fixture and Stage
needs. Do not promote V3 runtime scripts into V4 or count C1 provider-rule
candidates as full G03 governance coverage. C2b and later tranches require
their own exact Plans and Formal Pre before executable edits.

Formal Pre precedes the inventory edit. Run source-hash reconciliation,
isolated IFX package regression, unchanged published 1.1.2 Package check
and exact Formal Diff. Keep PATH-repair files, released/installed bytes and
the production Profile untouched.

## Verification record

Formal Pre passed before the inventory edit at
`artifacts/guards/p10-ifx-c2a/formal-pre`. A fresh local V3 Phase 9 replay
passed at `artifacts/guards/p10-ifx-c2a/v3-phase9/guard.json`: all 15 aggregate
checks, zero catalog errors and all 18 built-in mutation self-tests passed.
The closeout subreport remains `pre-ready` with three named blockers and was
not reclassified as approved closure. Independent reconciliation verified
all 19 source/authority hashes, all 15 check IDs and all 65 catalog error
codes against the frozen matrix. The isolated IFX package positive/negative
regression passed at
`artifacts/guards/v3-ifx-package-test-b23817952f8e488ba9c538bbe95b05aa`.
The receipted 1.1.2 Package check remains `pass` with hash
`922196c12917436b087c9c09361ca3669103992694eb5aa0ca8f2873ecc11a8d`.
This checkpoint is an inventory, not a C2 module or final Profile.
