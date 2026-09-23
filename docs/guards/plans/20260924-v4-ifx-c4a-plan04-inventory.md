# V4 P10.1 C4a — Plan04 governance inventory on 1.1.3

Status: `INVENTORY VALIDATED — executable C4a pending`

Freeze the six current Plan04 governance validators and their 45 nested
checks before V4 extension implementation. The current V3 result is
repository-passed, with extraction policy approval pending, production RLS
not claimed, and no reporting product claimed. Inventory exact projection,
extraction, tenant-query, boundary/dependency and retired-abstractions
authorities, including the five governed bypass entries. Keep dynamically
generated inventories as comparison evidence, not pre-approved V4 baselines.

This checkpoint edits only the Plan pair and claim-matrix pair. It neither
executes database migration nor approves extraction, tenant bypass, a
production Profile or the final bundle. Executable C4a work needs its own
Plan, Formal Pre, read-only module capability review, negative/missing/stale
and zero-subject controls, real IFX and 1.1.3 Host evidence.

## Verification record

Formal Pre passed at `artifacts/guards/p10-ifx-c4a/formal-pre` before
inventory edits. Fresh V3 replay passed at
`artifacts/guards/p10-ifx-c4a/plan04-baseline` with six validators and
45 nested booleans. Exact ID reconciliation, six detector hashes, eight
target policy hashes and five bypass entries were verified. The isolated
IFX package regression passed at
`artifacts/guards/v3-ifx-package-test-07a3d84fd8684d9c91c3540d5e05a7ba`;
the installed 1.1.3 Package check matched hash
`9dd609291c80f2e66aa44302e31bdc9bfc114b4f52f00e631f7c256c96766494`.
Exact Formal Diff from G05 protocol verification base `7cabd334` to
inventory candidate `45e268cc` passed at
`artifacts/guards/p10-ifx-c4a/formal-diff/summary-diff.json`, including the
V3 Stage Gate and exact four-path Plan scope.
