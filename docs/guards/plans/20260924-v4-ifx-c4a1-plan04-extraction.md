# V4 P10.1 C4a1 — Plan04 extraction policy

Status: `CANDIDATE VERIFIED — C4a remainder pending`

Translate the nine exact extraction-policy IDs in the Plan04 C4a matrix
into independent read-only V4 1.1.3 Post predicates. Validate the locked
decision schema and policy, actual positive and negative decision fixtures,
hard-gate non-bypass, bounded state transitions and application evidence.
Preserve the repository-passed / policy-approval-pending boundary; no
microservice extraction approval is inferred.

Require a nonzero blocking rule, real IFX and synthetic published-Host
Post, clean/violating/missing/stale/zero-subject controls, immutable roots,
isolated package regression and Formal Pre/Diff. The V3 detector and
historical report are comparison references, not the V4 executable.

## Verification record

Formal Pre passed at `artifacts/guards/p10-ifx-c4a1/formal-pre/pre.json`
before executable edits. All nine IDs map to one nonzero blocking Post
claim. Real IFX and published 1.1.3 synthetic Host Post passed with clean,
false microservice default, zero-fixture, missing-authority, stale-authority,
deterministic-repeat and immutable-root controls at
`artifacts/guards/p10-ifx-c4a1/test-runs/8bb57ce08ef14abe8f78b13b62fcd2bc/summary.json`.
The isolated package regression passed at
`artifacts/guards/v3-ifx-package-test-66f544d6026946118cb1deb90437eab5`.
Formal Diff is pending a committed candidate. Extraction
policy approval remains pending and no service extraction is authorized.
