# V4 P10.1 C4 pre-Database checkpoint

Status: `DOCUMENTATION CHECKPOINT — C4b pending decision`

Record verified candidate coverage on published V4 1.1.3 without
rewriting earlier time-stamped checkpoints. G05 context has 112 active
C4 IDs with candidate-level rules and eight Phase 9 IDs explicitly
required but deferred to P10.3. Plan05 has 13 candidate security checks.
Plan04 has 45 candidate governance checks across extraction, tenant-query,
projection and legacy Abstractions retirement. Each new tranche passed
real IFX and published-Host synthetic Post, negative/missing/stale/zero
controls, immutable roots, isolated IFX package regression, Formal Pre and
exact committed Formal Diff.

This is not an accepted final bundle, production Profile, G05 closure,
production security/Database approval, C5 Stage integration or P10.2
parity. C4b remains open pending the explicit choice between V4 Post
read-only verification of externally generated locked evidence and V4
Host-owned isolated `dotnet`/EF execution. No DB operation is authorized
by this checkpoint.

This documentation-only Plan updates the current program status and the
nine candidate verification records that still say Formal Diff is pending.
No runtime, bundle, release or installed bytes change.

## Verification record

Formal Pre passed at `artifacts/guards/p10-ifx-c4-pre-db/formal-pre/pre.json`.
The isolated IFX package regression passed its positive and negative cases
at `artifacts/guards/v3-ifx-package-test-46b80e9766214d088d20d5f76f2f72e9`.
Exact Formal Diff follows the scoped documentation commit.
