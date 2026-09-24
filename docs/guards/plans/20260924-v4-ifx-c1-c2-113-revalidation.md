# V4 P10.1 C1/C2 — published 1.1.3 revalidation

Status: `CANDIDATE REVALIDATED — C5/C6 still pending`

Revalidate the previously reviewed C1 Pre and C2 Post candidate rules on the
installed, receipted V4 1.1.3 release before C5/C6. The 1.1.2 records remain
historical and must not be relabelled. No published Package, installed release,
production Profile, module adapter, authority, or target input may be edited.

The 1.1.3 archive, receipt, source commit, Package hash and full installed file
inventory are pinned. Run each C1 and C2 unit suite with its original source
and fixture directory, adapting only the exact historical base-version/hash
literals and old base-verification call in an ephemeral script. Record source
and adapted script hashes, enforce exact replacement counts, and reject residual
1.1.2 identity. C1's overlapping rule IDs prevent claiming one combined Pre
Profile; these are separate Host Pre checks. Run C2e's five-module combined
Post Profile with its otherwise unchanged Profile bytes, a 1.1.3-specific
ephemeral authority lock, real IFX direct/dependency Post, synthetic negative
and zero controls, and fresh V3 G03 comparison. C1 applicability is separate.

For both stages require clean nonzero coverage, negative and zero-subject
controls, TargetRoot/PackageRoot invariance, and the suite's Host evidence.
Record any failure as a revalidation defect; do not infer C1 final closure or
C6 production bundle acceptance. C1 final closure still follows C5.

Formal Pre must pass on this Plan pair before executable edits. After tests,
run isolated IFX Package regression and exact Formal Diff against the Plan.

## Verification record

Formal Pre passed before executable edits at
`artifacts/guards/p10-ifx-c1c2-113/formal-pre/summary-pre.json`.
The published 1.1.3 archive, receipt, source commit, Package hash and all
137 installed files passed the pinned base checker. The revalidation summary
is `artifacts/guards/p10-ifx-c1c2-113/revalidation/6a33719885ee4a9faa3222be62cd1f19/summary.json`:
11 C1 Pre suites, five C2 Post suites, combined C2e and C1 applicability
passed (18/18), with original/adapted script hashes, refreshed C2e lock,
negative and zero controls, and unchanged installed root inventory.
Combined C2e passed real IFX direct/dependency Post with five modules and 16
nonzero claims, seven Host cases and four Profile rejection controls. Fresh V3
G03 Phase 9 passed while remaining `pre-ready` with three blockers; this is
not P10.2 full parity. The isolated IFX Package regression passed with
explicit repository NuGet configuration at
`artifacts/guards/v3-ifx-package-test-f613e63d8e614b3a95734e927191ac3f`.
The network-restricted first attempts failed on inaccessible user NuGet
configuration/network and are not counted as rule failures or successful
regression evidence. Formal Diff from `b2007582` to the committed candidate
passed at `artifacts/guards/p10-ifx-c1c2-113/formal-diff/summary-diff.json`,
including V3 Stage Gate and the exact four-path Plan scope.
