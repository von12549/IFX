# V4 P10.1 C2c2 — G03 compatibility snapshot candidate

Status: `CANDIDATE VALIDATED — C2d/C2e pending`

Build a read-only Post extension for the two committed G03 compatibility
snapshots. Derive the sync API and serialization projections afresh from the
current catalog and the actual sync interface methods under TargetRoot/src,
using the ordering and shape of the V3 generator. Compare the complete
projections with the committed `G03-sync-api-snapshot.json` and
`G03-serialization-golden.json`. Reject absent, malformed, stale, empty or
nondeterministic inputs; do not regenerate or change the target snapshots.

Lock the reviewed catalog, both snapshots, V3 snapshot generator and
candidate authorities by SHA-256. Exercise clean, drift, missing, malformed,
zero-subject, generated-source and linked-path controls; prove deterministic
results and TargetRoot byte invariance. Validate against the real IFX tree,
synthetic published V4 1.1.2 Host Post, isolated V3 package regression and
Formal Pre/Diff. Formal Pre must precede executable edits.

This candidate does not modify a production Profile or published Package.
C2d documentation/closeout and C2e combined Stage/parity remain separate;
C2c2 alone cannot close C2 or G03. Existing PATH-repair changes are outside
this Plan.

## Verification record

Formal Pre passed before executable edits at
`artifacts/guards/p10-ifx-c2c2/formal-pre`. Sixteen clean, violating,
missing, malformed and zero-subject fixtures, hash/link controls,
determinism and TargetRoot byte invariance passed. The real IFX tree
produced four sync API signatures and six serialization schemas matching
the committed snapshots. Synthetic-only published V4 1.1.2 Host Post
passed; evidence is under
`artifacts/guards/p10-ifx-c2c2/test-runs/6acd5761401e43c6b429eefc9edb02da`.
The isolated IFX package regression passed at
`artifacts/guards/v3-ifx-package-test-7363dc7b899048aca422e3ec49cff24e`.
Formal Diff from C2c1 base `f2b88bb4` to candidate `b2232b0a` passed at
`artifacts/guards/p10-ifx-c2c2/formal-diff/summary-diff.json`, including
the V3 Stage Gate regression and exact 12-path Plan scope. No PATH-repair
or production Profile paths were included.
