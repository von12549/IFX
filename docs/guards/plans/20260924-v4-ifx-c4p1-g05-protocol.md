# V4 P10.1 C4p1 — G05 protocol primitives on 1.1.3

Status: `CANDIDATE VERIFIED — G05 remainder pending`

Implement the eleven G05 Phase 1 protocol-primitives checks as a bounded,
read-only Post candidate. Check dependency-free context/messaging contract
projects, strong identifiers, explicit scopes and references, versioned
Contract/Event shapes, forbidden framework/transport leakage, G03 primitive
admission and Phase 1 test/evidence authorities. Freeze exact current
TargetRoot hashes; fail closed on missing, stale, violating and zero-subject
cases with three blocking claims. Validate the module and its config against
published V4 1.1.3 schemas, then run real IFX and synthetic-only Host Post.

The remaining 109 G05 context checks and 13 Plan05 security checks remain
pending, as do C4a Plan04 and C4b Database. This candidate does not establish
G05 closure, production approval or P10.2 parity. Formal Pre precedes module
edits; exact Diff and isolated IFX package regression close the tranche.

## Verification record

Formal Pre passed before executable edits at
`artifacts/guards/p10-ifx-c4p1/formal-pre`. Eleven exact Phase 1 check IDs
were reconciled with the C4 inventory. Six clean, violation, missing,
stale and zero-subject fixtures, deterministic repeat, real IFX direct scan,
schema/authority checks, synthetic-only 1.1.3 composition and Host Post,
and TargetRoot/PackageRoot byte invariants passed at
`artifacts/guards/p10-ifx-c4p1/test-runs/cb00f93916a1449b85a5d5dffd198a12`.
Published archive/receipt and Package hashes matched 1.1.3. The isolated
IFX package regression passed at
`artifacts/guards/v3-ifx-package-test-d1b9dcf0754447e39571a1f1fa0468d9`.
Exact Formal Diff from inventory verification base `888610ac` to candidate
`a0ca4a9a` passed at
`artifacts/guards/p10-ifx-c4p1/formal-diff/summary-diff.json`, including the
V3 Stage Gate and exact eleven-path Plan scope. No G05 closure or production
Profile is inferred.
