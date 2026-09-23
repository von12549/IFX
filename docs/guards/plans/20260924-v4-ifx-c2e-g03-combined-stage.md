# V4 P10.1 C2e — combined G03 Post candidate

Status: `CANDIDATE VALIDATED — final C6/P10.2 acceptance pending`

Compose the five C2b1/C2b2/C2c1/C2c2/C2d modules into one reviewable
candidate Profile bound to the published V4 1.1.2 base. Freeze the exact
module manifests, selected claims/rules, target authority hashes and zero
baselines. Validate both direct Post and `--with-dependencies` Post on the
same real IFX TargetRoot, with four immutable roots and fresh evidence per
run. The combined stage must have 16 nonzero claims and no unreviewed waiver.

Exercise clean, violating, missing/stale authority and zero-subject aggregate
controls; missing module/claim/rule and baseline injection must fail before
or during composition. Compare the current clean V4 result with a fresh V3
G03 Phase 9 replay: both must pass, with V3 remaining `pre-ready` and three
explicit blockers. Record any semantic divergence rather than inferring
full P10.2 parity from this checkpoint. Neither candidate modules nor V3
runtime code may be silently changed to make the comparison pass.

Formal Pre precedes executable/profile edits. Preserve the installed base,
published Package, production IFX Profile and existing PATH-repair files.
C2e may close G03 *candidate coverage* only. Final bundle byte review by
Xiaolong Feng, receipted operational composition and Web UI practice belong
to C6; independent frozen-corpus V3/V4 parity belongs to P10.2.

## Verification record

Formal Pre passed before executable/profile edits at
`artifacts/guards/p10-ifx-c2e/formal-pre`. The static Profile/authority
locks, four Profile rejection controls, seven synthetic published-Host cases,
TargetRoot/PackageRoot invariance and fresh V3 Phase 9 replay passed. The
candidate-level summary is
`artifacts/guards/p10-ifx-c2e/test-runs/ca625166ed2e4a0b874d583999d8f0dd/summary.json`.
Both real IFX Post modes passed with five modules and 16 nonzero claims;
V3 passed all 15 aggregate checks while remaining `pre-ready` with three
blockers. The isolated IFX package regression passed at
`artifacts/guards/v3-ifx-package-test-7ec8e6cd32484fdb8beb6700f39c4f0d`.
Formal Diff from C2d base `b7c06771` to candidate `a4849752` passed at
`artifacts/guards/p10-ifx-c2e/formal-diff/summary-diff.json`, including V3
Stage Gate and exact seven-path Plan scope. The published Package, production
IFX Profile and PATH-repair files were not changed.
