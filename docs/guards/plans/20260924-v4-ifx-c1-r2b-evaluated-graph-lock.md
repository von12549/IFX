# V4 P10.1 C1 R2b — evaluated reference graph lock

Status: `EXECUTION PLAN — R2B ONLY; C1 BLOCKED`

R2a proved the 58-project Release/net8.0 MSBuild item-evaluation interface and
the raw-scan blind spot for `Directory.Build.props` and explicit imports. R2b
will produce a short-lived, content-bound evaluated graph outside the Host and
verify it in a read-only V4 Post module. The verifier will independently apply
the pinned C1 reference direction, allow-list and ownership rules to evaluated
edges. Raw Pre remains in force. No published or installed 1.1.3 byte changes.

The producer must fail on missing, linked, escaping or unapproved imports,
unresolved references, project-set or SDK/TFM drift, nonzero exit, malformed
output and zero subjects. It records the exact source/import hashes, evaluated
edges and defining projects, raw/evaluated delta, target commit, evaluation
arguments, issuance and expiry. It invokes item evaluation only, not build
targets. The Post module independently verifies all lock inputs against current
TargetRoot bytes and rejects stale or tampered evidence, then evaluates the C1
policy with nonzero coverage. Synthetic props/import and conditional edges
must demonstrate a forbidden evaluated-only edge blocks.

The governed test composes a synthetic-only extension on published 1.1.3,
exercises direct and dependency Host Post plus negative controls, verifies
TargetRoot/PackageRoot immutability, and runs package regression. Formal Pre
must pass before executable edits; exact Formal Diff follows the commit.
Generated C# applicability and integrated C1 identity remain R2c/R3, so R2b
alone cannot close C1 or start C6.

## Verification record

Formal Pre passed at
`artifacts/guards/p10-ifx-c1-r2b/formal-pre/summary-pre.json`.
The controlled Release/net8.0 graph has 58 projects, 155 evaluated direct
references and 147 in-scope C1 reference subjects. Published 1.1.3 Host Post
passed in direct and dependency modes on a synthetic-only extension. Isolated
58-project fixtures injected one forbidden evaluated-only reference through
`Directory.Build.props` and through an explicit project `<Import>`; each kept
155 raw references, produced 156 evaluated references, and blocked in Post.
Missing, stale, empty and hash-altered locks, a forged forbidden edge,
missing/escaping imports and an unresolved reference also blocked. The
record is `artifacts/guards/p10-ifx-c1-r2b/test-runs/5c87ad16738c4e4d9b9a4aa6ee01a263/summary.json`.
The isolated IFX package regression passed at
`artifacts/guards/v3-ifx-package-test-1a122a1e2232487e9b322e68be999ea2`.
Exact Formal Diff follows the scoped commit. The generated-input and
integrated-identity obligations are expressly still open.
