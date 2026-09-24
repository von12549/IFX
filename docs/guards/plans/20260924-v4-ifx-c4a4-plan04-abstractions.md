# V4 P10.1 C4a4 — Plan04 legacy Abstractions retirement

Status: `CANDIDATE VERIFIED — C4b pending`

Translate the eleven exact Plan04 `Abstractions` retirement IDs into
independent read-only V4 1.1.3 Post predicates over the current solution,
project directories/references, source namespaces and six fixtures. For
the two LayerGuard claims, bind the existing V4 C1j project-name and C1n
reference-policy candidate authorities; do not import the V3 LayerGuard
policy or detector at V4 runtime. Preserve the distinction between
retired IFX project names and permitted third-party `*.Abstractions`
packages or historical fixtures.

Require a nonzero blocking rule, real IFX and synthetic published-Host
Post, violation/missing/stale/zero-subject and immutable-root controls,
isolated package regression and Formal Pre/Diff.

## Verification record

Formal Pre passed at `artifacts/guards/p10-ifx-c4a4/formal-pre/pre.json`
before executable edits. All eleven IDs map to one nonzero blocking
Post claim. Real IFX and published 1.1.3 synthetic Host Post passed with
clean, legacy-directory, zero-source, missing-authority, stale-authority,
deterministic-repeat and immutable-root controls at
`artifacts/guards/p10-ifx-c4a4/test-runs/d2acd9ffb2bb49289716f677680b5d72/summary.json`.
The isolated package regression passed at
`artifacts/guards/v3-ifx-package-test-04379d532258465e86f5902f2c034d55`.
Formal Diff is pending a committed candidate. The two
LayerGuard-related claims bind V4 C1j/C1n candidate policy, not V3 runtime
files; production bundle acceptance is not inferred.
