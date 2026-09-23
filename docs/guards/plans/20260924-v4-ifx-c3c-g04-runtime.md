# V4 P10.1 C3c — G04 runtime and inbound boundary candidate

Status: `CANDIDATE VALIDATED — C3d/C3e pending`

Port the 47 C3c-mapped G04 Phase 12 and Plan02-C1 checks to a read-only
Post extension on the published V4 1.1.3 Host. Review each source/evidence
predicate explicitly: runtime roles, startup ordering, worker identity and
lease, drain, health, backpressure and raw inbound context validation. Bind
the current TargetRoot authorities by exact Profile hashes; the V3 scripts
remain comparison inputs and are never executed from the extension.

The candidate must fail closed on missing/stale/malformed authority, source
violation, and zero subjects; use targeted clean/negative/zero fixtures,
nonzero coverage and immutable TargetRoot/PackageRoot checks. Exercise a
synthetic-only 1.1.3 Host Post composition. Existence of a test or evidence
document is only a source claim, not proof that the referenced test passed
in this run. C3d owns current documentation and closeout, and C3e owns the
combined current V3/V4 comparison.

Formal Pre precedes executable edits; exact Formal Diff, isolated IFX
package regression and receipted 1.1.3 Package identity are required.
No production Profile, release or IFX cutover is authorized here.

## Verification record

Formal Pre passed before executable edits at
`artifacts/guards/p10-ifx-c3c/formal-pre`. The exact 47 policy predicate IDs
match the C3 matrix; seven blocking Host claims and 20 source/evidence
authority hashes passed module and schema checks. Twelve direct clean,
violating, missing, stale and zero-subject fixtures, deterministic repeats,
real IFX scan and synthetic-only composition/Host Post on the receipted
1.1.3 base passed at
`artifacts/guards/p10-ifx-c3c/test-runs/54442807b1d44300a83f70dc92b92f66`.
TargetRoot and PackageRoot stayed byte-invariant. Published archive and
Package hashes were `28307116aca1361e9eed5fdcd284a58cdfdb8fd3728869f09dd13f4c9a49b02e`
and `9dd609291c80f2e66aa44302e31bdc9bfc114b4f52f00e631f7c256c96766494`.
The isolated IFX package regression passed at
`artifacts/guards/v3-ifx-package-test-b9ae7c21a18147d4811f2358df5874c1`.
V3's absent `AddMessaging()` token creates a vacuous ordering pass; the V4
candidate requires the present `AddReliableMessaging(` token before module
registration. This divergence remains explicit for C3e/P10.2.
Formal Diff awaits the exact candidate commit.
