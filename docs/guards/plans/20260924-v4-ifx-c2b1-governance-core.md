# V4 P10.1 C2b1 — G03 governance core candidate

Status: `CANDIDATE VALIDATED — partial C2b only`

C2a found 65 active G03 catalog error codes plus 15 Phase 9 aggregate checks.
This child Plan ports the first bounded governance group to a read-only Post
extension: owner/backup and consumer references, module ownership, provider
and adapter edges, mixed/synchronous cycles, shared primitive and BCL-only
contract policy, waiver policy and catalog-to-LayerGuard projection parity.
Bind the current G03 catalog and generated projection via Profile config hashes
and the candidate policy hash. Freeze V3 source/policy hashes for review, but
do not execute or copy V3 runtime code.

The module must reject missing/stale/malformed catalog or projection, linked
paths, inconsistent owners/consumers/providers, a cycle, altered projection,
invalid/unwaivable/expired waiver and missing active governance subjects.
Zero waiver entries are valid when the waiver policy itself is present and
checked: V3 permits the current exact zero-waiver state. Test clean, violating,
missing, stale and zero-subject cases with TargetRoot byte invariance, module
and schema contracts, synthetic-only published-Host Post, package regression,
Package identity, Formal Pre before executable edits and exact Formal Diff.

This is not all of C2b. C3/C4 field classification, sensitive-use evidence,
full protocol lifecycle/admission, public-surface migration, change records,
documentation and closeout remain separate C2b2/C2c/C2d obligations. No
production Profile or final bundle is accepted by this candidate.

## Verification record

Formal Pre passed before executable edits at
`artifacts/guards/p10-ifx-c2b1/formal-pre`. The read-only Post candidate
passed 20 clean/negative/missing/zero fixtures plus hash drift, linked-path,
determinism and TargetRoot byte-invariance controls. It also passed against
the real G03 catalog and via a synthetic-only Post composition of published
V4 1.1.2 Host; evidence is under
`artifacts/guards/p10-ifx-c2b1/test-runs/8eeba23615b34ec38a6317f65cb1be3b`.
The isolated V3 IFX package positive/negative regression passed at
`artifacts/guards/v3-ifx-package-test-ed86000ed7eb45eb8896462c80758bb6`.
Published Package identity passed with Package hash
`922196c12917436b087c9c09361ca3669103992694eb5aa0ca8f2873ecc11a8d`.
The first package run was sandbox-blocked at NuGet restore; the permitted
rerun passed. Exact Formal Diff passed against the C2a base at
`artifacts/guards/p10-ifx-c2b1/formal-diff/summary-diff.json`. No unrelated
PATH-repair or production Profile paths were included.
