# V4 P10.1 C2b2 — G03 residual catalog semantics candidate

Status: `CANDIDATE VALIDATED — C2b semantic coverage`

C2b1 covers owner/consumer references, provider graph, shared primitive,
waiver and LayerGuard projection. C2b2 covers the remaining catalog
governance semantics: catalog/source-policy and approval nodes; protocol
identity, lifecycle, admission and evidence; infrastructure-sensitive
boundary; field classification, C3 exception and C4 exclusion, surface and
sensitive-use policy; legacy public-surface disposition and deadline; change
records and minimization evidence. Preserve the frozen V3 catalog/script
hashes for review, but do not invoke V3 runtime code from the extension.

This is a read-only Post extension bound to an explicit catalog hash via
synthetic Profile config. Verify clean, violating, missing, stale, malformed
and zero-subject inputs, deterministic findings, no TargetRoot byte changes,
schema/authority locks, published 1.1.2 Host composition, isolated package
regression, Package identity and Formal Pre/Diff. Formal Pre must precede
executable edits. No production Profile or final bundle is accepted here.

Source-field reconciliation (`field-source-missing` and
`field-source-drift`), fresh inventory and deterministic API/schema snapshots
belong to C2c. Bilingual documentation, closeout state and blockers belong
to C2d. Combined stage/parity and final acceptance belong to C2e. V3's
`self-test` report error is represented by the V4 candidate's own negative
fixture suite rather than a runtime catalog predicate.

## Verification record

Formal Pre passed before executable edits at
`artifacts/guards/p10-ifx-c2b2/formal-pre`. The candidate passed 46
clean/negative/missing/zero fixtures, stale hash and linked-path controls,
real IFX catalog evaluation, deterministic results, TargetRoot byte
invariance and a synthetic-only published V4 1.1.2 Host Post composition.
Final candidate evidence is under
`artifacts/guards/p10-ifx-c2b2/test-runs/123da4c45f0c432fa8e28cf3fade7543`.
The C2a matrix has 63 C2b catalog error codes: 62 are represented across
C2b1/C2b2 and the V3 `self-test` result is replaced by the candidate
negative-control suite. This mapping is checked by the C2b2 test.
The isolated IFX package positive/negative regression passed at
`artifacts/guards/v3-ifx-package-test-a2c925721fff4830b00646238d7dc754`.
Published Package identity remained `pass` at Package hash
`922196c12917436b087c9c09361ca3669103992694eb5aa0ca8f2873ecc11a8d`.
Exact Formal Diff passed against the C2b1 base at
`artifacts/guards/p10-ifx-c2b2/formal-diff/summary-diff.json`. No PATH-repair
or production Profile paths were included.
