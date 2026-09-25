# C6c16 G03 snapshot scan decision

Decision: keep the `ifx-g03-snapshots` 60-second capability ceiling and reduce
filesystem enumeration cost without changing snapshot semantics.

## Failure isolated

The C6c15 parallel certification completed all 37 Windows suites and all C6c5
controls, but Linux direct-post returned `adapter-failure` because only
`ifx-g03-snapshots` timed out. The preceding
`ifx-g03-source-reconciliation` module passed, proving the C6c15 repair.

The snapshots adapter performed two deterministic projections. Each projection
materialized and sorted every directory entry as PowerShell objects before
discarding all files except `.cs` and `.csproj` inputs.

## Change

`Source-Files` now uses .NET directory enumeration with a FIFO queue, rejects
reparse-point directories and files, prunes `bin` and `obj`, and enumerates only
top-level `*.cs` and `*.csproj` inputs in each accepted directory. The adapter
still performs two independent projections and retains the same sorting,
signature extraction, snapshot comparison, findings, and coverage behavior.

No timeout, rule, claim, policy, snapshot, waiver, or baseline changed.

## Verification

- Formal Pre passed:
  `artifacts/guards/p10-ifx-c6c16/formal-pre/summary-pre.json`.
- The owning C2c2 suite passed 16 fixtures and controls plus real snapshot
  parity:
  `artifacts/guards/p10-ifx-c6c16/owning-c2c2/f83d5dfd9cd54cd1a110a14cfd258533`.
- The combined C2e suite passed 7 Host cases, 4 Profile rejection controls, and
  a fresh V3 Phase 9 run:
  `artifacts/guards/p10-ifx-c6c16/combined-c2e/dc43707e3742408bb530ca98a0d06601`.
- The complete C2c2 suite passed in the locked Linux image
  `ifx-c6c-sdk:10.0.303`.
- A direct real-repository adapter run in that image returned `pass`, matched 4
  sync API subjects and 6 serialization subjects, and completed in 43.703
  seconds, below the unchanged 60-second ceiling.
- The refreshed 37-module/83-rule development inventory is:
  `artifacts/guards/p10-ifx-c6c16/development-inventory/47c2ce11cd48422689b5fd25c63cb984/ordinal-inventory.json`.
- The refreshed inventory projection is
  `4e33f74f50b6e4e63ea670e87ba28e44676f12b12083e2a602d01279d8aacbe4`;
  the matrix contract and supplemental fixture binding passed at
  `artifacts/guards/p10-ifx-c6c16/matrix-contract/summary.json`.

Final acceptance remains contingent on the refreshed inventory bindings and a
fresh same-commit C6c parallel certification.
