# V4 P10.1 C3b — G04 manifest and release-policy candidate

Status: `CANDIDATE VALIDATED — C3c–C3e pending`

Implement the 12 C3b-mapped G04 Phase 12 checks as a read-only Post
extension against the published, receipted V4 1.1.3 base. The candidate
must freshly validate the deterministic runtime inventory predicates, exact
business and deployment-unit subjects, module/deployment manifests and eight
release bindings, schema compatibility, dependency criticality, ordered
backpressure thresholds, consumer-first release orchestration and failure
matrix. Freeze the current TargetRoot authority hashes in Profile config and
the reviewed module policy. Do not treat a structure-only release plan as
completed production evidence; the G04 closeout remains `PRE-READY`.

Missing, stale, malformed, duplicate, contradictory and zero-subject inputs
must block. Supply targeted fixture mutations and deterministic results,
verify nonzero claim coverage and TargetRoot/PackageRoot byte invariance,
then exercise a synthetic-only Post composition against the installed 1.1.3
Host. The V3 scripts are comparison authorities, never V4 runtime imports.

Formal Pre must pass before executable/profile edits. Exact Formal Diff,
isolated IFX package regression and published 1.1.3 Package check are
required. C3c source/runtime and inbound checks, C3d docs/closeout and C3e
combined acceptance remain separate. No production Profile or final bundle
is approved by this Plan.

## Verification record

Formal Pre passed before executable edits at
`artifacts/guards/p10-ifx-c3b/formal-pre`. The module, schema, policy and
rule-plan hash checks passed. Sixteen direct fixtures (clean, malformed,
missing, stale, contradictory, duplicate and zero subjects), deterministic
repeats and the real IFX direct run passed at
`artifacts/guards/p10-ifx-c3b/test-runs/9f064fb2134649ce8f1cabe4cfdc36a7`.
Synthetic-only composition and Host Post passed using the receipted 1.1.3
installation and the published archive SHA-256
`28307116aca1361e9eed5fdcd284a58cdfdb8fd3728869f09dd13f4c9a49b02e`;
the Package check returned
`9dd609291c80f2e66aa44302e31bdc9bfc114b4f52f00e631f7c256c96766494`.
TargetRoot and PackageRoot were byte-invariant. The isolated IFX package
regression passed at
`artifacts/guards/v3-ifx-package-test-29027a4fa674461abb59466c2574befa`.
The checked-in release artifact digest and current project-file hash differ;
the candidate preserves that V3 semantic boundary and records it for C3e.
Formal Diff awaits the exact candidate commit. No production release or
Profile was accepted.
