# V4 P10.1 C4p4/p5 — G05 Contract and Event carrier conformance

Status: `CANDIDATE VERIFIED — G05 remainder pending`

Translate the exact nine Phase 4 Contract-context and ten Phase 5 Event
propagation checks in the frozen G05 matrix into a read-only V4 Post
candidate on published 1.1.3. Distinguish fake-carrier conformance from
real Plan01/Plan02 integration and durability; the latter remains pending
and must not be represented as passed. Lock policy, schema, golden envelope,
source and conformance-test authorities. Validate order, identifiers,
failure codes, actor/scope payload restrictions, logical/delivery separation,
retry/replay and bounded trace/tenant rejection semantics.

Require a predicate for each of the 19 IDs, a nonzero blocking rule for each
phase, clean and targeted violation, missing/stale and zero-subject controls,
real IFX and synthetic published-Host Post, with immutable roots. Do not
execute or copy V3 detector runtime code. Formal Pre precedes edits; package
regression and exact Diff close only this candidate tranche.

## Verification record

Formal Pre passed before executable edits at
`artifacts/guards/p10-ifx-c4p4p5/formal-pre/summary-pre.json`.
All 19 matrix IDs map to two blocking Post claims, with current source,
schema, golden, policy and evidence authorities hash-locked. Real IFX and
published 1.1.3 synthetic Host Post passed both nonzero claims. Clean,
contract-status violation, event-status violation, zero-subject,
missing-authority and stale-authority controls, deterministic repeat and
immutable TargetRoot/PackageRoot passed at
`artifacts/guards/p10-ifx-c4p4p5/test-runs/55d0615491714d348d560f810b21b566/summary.json`.
The isolated IFX package regression passed at
`artifacts/guards/v3-ifx-package-test-d99fba2697744b22bfad1a3e24272ff9`.
Formal Diff is pending a committed candidate. Real Plan01/Plan02 carrier
acceptance and durable messaging are not claimed by these fake-carrier tests.
