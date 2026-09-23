# V4 P10.1 C3a — G04 Phase 12 claim inventory on 1.1.3

Status: `INVENTORY VALIDATED — C3 implementation pending`

The current development branch contains the published and receipted V4 1.1.3
PATH-isolation patch. C3 and the subsequent C4 series use the immutable
1.1.3 installation as their Host base. Historical C1/C2 evidence remains
bound to 1.1.2; a separately planned 1.1.3 revalidation of those candidates
is mandatory before C5/C6 integration, without rewriting historical results.

Freeze the exact G04 Phase 12 and Plan02-C1 inbound checks, detector hashes,
release/runtime bindings, source authorities, current `PRE-READY` closeout,
freshness and zero-subject requirements. Map every active check to a bounded
V4 destination before executable changes. Distinguish base-owned V3 judging
code from TargetRoot declarations and generated inventory. Do not copy V3
runtime code into V4 or infer production approval from a clean current replay.

This is a documentation-only checkpoint. It authorizes no bundle,
production Profile, external deployment or source mutation. C3 implementation
requires its own exact child Plan and Formal Pre; C4, C4a and C4b likewise
remain separate tranches. Formal Pre precedes inventory changes and exact
Formal Diff verifies the five declared paths.

## Verification record

Formal Pre passed at `artifacts/guards/p10-ifx-c3a/formal-pre` before the
matrix and program transition edit. A fresh V3 G04 replay passed at
`artifacts/guards/p10-ifx-c3/g04-baseline`: 70 Phase 12 checks and 12
Plan02-C1 inbound checks, while closeout stayed `PRE-READY`.
Independent reconciliation found all 82 check IDs in order, and verified
10 detector and 12 target-authority hashes. The installed 1.1.3 Package
check passed with hash
`9dd609291c80f2e66aa44302e31bdc9bfc114b4f52f00e631f7c256c96766494`.
The isolated IFX package regression passed at
`artifacts/guards/v3-ifx-package-test-c5b0d4a359c44e97bdc6968e787698bb`.
Exact Formal Diff from base `c3e05523` to inventory commit `c00848e7`
passed at `artifacts/guards/p10-ifx-c3a/formal-diff/summary-diff.json`,
including the Stage Gate and five-path Plan scope. No C3 module, production
Profile or final bundle was accepted by this inventory.
