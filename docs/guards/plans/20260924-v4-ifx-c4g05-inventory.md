# V4 P10.1 C4 G05 inventory — Phase 11 and Plan05 security

Status: `INVENTORY VALIDATED — executable C4 pending`

Freeze the current V3 G05 Phase 11 and Plan05 security-boundary checks before
building V4 extensions on the published, receipted 1.1.3 base. Enumerate
every check ID and detector hash; separate G05 context/protocol, evidence and
documentation checks from the Plan05 security claims. Record the current
`pre-ready` status, seven blockers and eight C3 field exceptions. Reconcile
the source-bound target policy anchors and dynamically scanned source roots.

This inventory is not an implementation or production Profile. Subsequent
C4 executable tranches require their own exact Plan, Formal Pre, module
capabilities, negative/zero controls, real IFX and 1.1.3 Host evidence.
No V3 detector is copied as V4 runtime code. Formal Pre and exact Diff apply
only to this Plan pair and inventory pair.

## Verification record

Formal Pre passed before inventory edits at
`artifacts/guards/p10-ifx-c4/formal-pre`. Fresh V3 replay passed at
`artifacts/guards/p10-ifx-c4/g05-baseline`: 120 context and 13 Plan05
security checks. Independent enumeration retained all 133 unique check IDs,
four detector hashes, twelve target policy hashes and the G05 status hash.
The status remained `pre-ready`, seven blockers and eight C3 exceptions.
The isolated IFX package regression passed at
`artifacts/guards/v3-ifx-package-test-376f178fac9d47119788a3df9965b82d`;
the installed 1.1.3 Package check matched hash
`9dd609291c80f2e66aa44302e31bdc9bfc114b4f52f00e631f7c256c96766494`.
Exact Formal Diff from C3e verification base `26ebeb42` to inventory
candidate `f812e996` passed at
`artifacts/guards/p10-ifx-c4/formal-diff/summary-diff.json`, including the
V3 Stage Gate and exact four-path Plan scope.
