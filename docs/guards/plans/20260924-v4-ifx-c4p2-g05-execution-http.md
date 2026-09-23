# V4 P10.1 C4p2 — G05 execution and HTTP boundaries on 1.1.3

Status: `CANDIDATE VERIFIED — G05 remainder pending`

Implement the exact 19 G05 Phase 2–3 checks in a read-only V4 Post module.
Cover the application execution-context port, bounded AsyncLocal lifetime,
composition and identity/tenant split, five fail-closed sources, middleware
ordering, public correlation/trusted gateway, W3C trace restart, tenant
rejection, route metadata, safe HTTP errors, integration tests and phase
evidence. Use current TargetRoot source/policy hashes and at least two
blocking claims with no baseline. Exercise clean, violating, missing, stale
and zero-subject controls, real IFX, synthetic-only 1.1.3 Host Post and
immutable roots.

The remaining G05 phases, Plan05 security, Plan04 and Database still require
separate implementation. This Plan does not approve a production Profile,
declare G05 closure or establish P10.2 parity. Formal Pre precedes
executable edits; exact Diff, isolated IFX package regression and published
1.1.3 identity close this tranche.

## Verification record

Formal Pre passed at `artifacts/guards/p10-ifx-c4p2/formal-pre` before
executable edits. Nineteen exact Phase 2–3 check IDs map to two blocking
claims with current source, policy, test and evidence hashes. Seven direct
clean/violation/missing/stale/zero fixtures, deterministic repeats, real IFX
scan, synthetic-only 1.1.3 composition and Host Post, and TargetRoot/PackageRoot
byte invariants passed at
`artifacts/guards/p10-ifx-c4p2/test-runs/7a68d46adcf34a1291d53aa4d42d882a`.
The presentation source set is hash-bound and route-group scope metadata is
non-vacuous. The published archive, receipt and Package hash matched 1.1.3.
The isolated IFX package regression passed at
`artifacts/guards/v3-ifx-package-test-ce6f1c5069d241da903f6ed24079636e`.
Exact Formal Diff awaits the candidate commit. No production Profile or
G05 closure is claimed.
