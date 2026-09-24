# V4 P10.1 C5f — full reviewed Post claim integration

Compose a synthetic-only V4 1.1.3 candidate containing all 24 reviewed
C2–C5 Post modules: five G03, three G04, twelve C4 and four C5. Resolve
each exact config from a committed C2/C3 Profile, a passing C4 fixture
record, or fresh C5/C4b evidence locks; validate schema, module bytes,
unique rule/claim identity and zero baselines. Run direct and
dependency-enabled Post on real IFX and preserve every blocking result,
including the seven G04 `PRE-READY` governance blockers as external status,
not a V4 waiver. Test missing evidence and baseline injection. Bind the
separate C1 Pre 1.1.3 revalidation summary because its overlapping rule IDs
cannot be represented by this one Post Profile.

This is a candidate integration audit, not C6 final bundle approval or
P10.2 parity. If any module config is synthetic-only or stale against the
real root, stop and repair that tranche instead of silently relabelling it.
Diff/CI and G05 Phase 9 remain P10.3 deferred. Fresh locks expire after
24 hours and must be regenerated before any later acceptance.

## Verification record

Formal Pre passed at
`artifacts/guards/p10-ifx-c5f/formal-pre/summary-pre.json`.
The published 1.1.3 archive, receipt and installed Package hashes matched.
The synthetic-only combined Profile loaded all 24 reviewed C2–C5 Post
modules (five C2, three C3, twelve C4 and four C5), with 54 unique
blocking rules/claims and zero baseline references. Both direct Post and
dependency-enabled Bootstrap → Analysis → Pre → Post passed on the real IFX
root, each with 24 module results, 54 covered claims and 1,468 matches.
The separate C1 Pre 1.1.3 revalidation summary was checked by hash because
C1 and Post rule IDs overlap. The seven G04 `PRE-READY` blockers were
preserved as an external governance status, not masked by the candidate.
Missing Solution evidence blocked with `prerequisite-missing`; an
undeclared baseline was rejected during composition. Package bytes and
all four fresh evidence-lock files remained unchanged. The result is
`artifacts/guards/p10-ifx-c5f/test-runs/2ed76a91a7c9432fa35f0d59dd5a5f78/summary.json`.

The isolated IFX package regression passed at
`artifacts/guards/v3-ifx-package-test-a69086f9508a4f9fbef53693ae0794bf`.
Exact Formal Diff is pending. C5f is candidate-level integration, not
a reviewed C6 bundle, G04 closure, P10.2 parity or P10.3 CI transition.
