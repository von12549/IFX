# V4 P10.1 C4a2 — Plan04 tenant-query governance

Status: `CANDIDATE VERIFIED — C4a remainder pending`

Translate the twelve exact Plan04 tenant-query IDs to independent read-only
V4 1.1.3 Post predicates. Inspect locked policy, the five-entry bounded
cross-tenant bypass registry, current repository methods and contracts,
source-wide ordinary bypasses, and positive/negative fixture behavior.
Preserve `repository-passed-production-rls-not-claimed`: no production RLS
attestation follows from source checks. Do not import V3 detector code.

Require a nonzero blocking rule, real IFX and synthetic published-Host
Post, violation/missing/stale/zero-subject and immutable-root controls,
isolated package regression and Formal Pre/Diff.

## Verification record

Formal Pre passed at `artifacts/guards/p10-ifx-c4a2/formal-pre/pre.json`
before executable edits. All twelve IDs map to one nonzero blocking Post
claim. Real IFX and published 1.1.3 synthetic Host Post passed with clean,
unguarded-tenant, zero-source, missing-authority, stale-authority,
deterministic-repeat and immutable-root controls at
`artifacts/guards/p10-ifx-c4a2/test-runs/4a3f6ffd6a374bfa91a97f0a868cb40f/summary.json`.
The isolated package regression passed at
`artifacts/guards/v3-ifx-package-test-a0063ea52a684bcdaff09de2449d6bcc`.
Formal Diff is pending a committed candidate. Production
row-level security remains explicitly unclaimed.
