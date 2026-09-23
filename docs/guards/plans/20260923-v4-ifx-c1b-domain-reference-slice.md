# V4 P10.1 C1b — direct Domain-to-Contracts reference slice

Status: `CANDIDATE SLICE TESTED — exact Formal Diff pending; no production acceptance`

C1a proposed `L1.2`/`L2.9` as the first project-topology pair. Source-code
inspection exposed a semantic mismatch: `OWNERSHIP-UNKNOWN` is about whether
the V3 reader infers any module string (including its parent-folder fallback),
not catalog registration; `PROJECT-NAME-FORBIDDEN` is applied only to
in-scope Ring projects, while the separate Plan04 retirement detector checks
Abstractions names across directories, projects, references and solution
entries. A stricter name or catalog check cannot be reported as a faithful
port of those two V3 rules. Correct the C1a destination and defer both to a
separately reviewed tranche and Plan04 coordination.

This C1b instead implements one non-vacuous, bounded part of `L2.2`: a direct
raw `.csproj` ProjectReference from an IFX Domain project to an IFX Contracts
project. This is **not** the full `RING-DIRECTION` graph/transitive rule or
`IMPORT-DIRECTION`, and does not close `v3-architecture`. The V3 source rule
file is `docs/guards/V3_ifx/stages/post/rules/L2.2.json` with SHA-256
`3061250248352bc621763df6ed6f087e2795104ee642244081858fdd90892145`;
the IFX policy is
`b89172e667a3e5c51b4d065cc325a99ea293aa2696a548980c8125d9c0323fb5`.

## Candidate contract

Create an uncomposed workbench module `ifx-domain-reference` for V4 Pre,
using only the public PowerShell adapter interface. The module reads scoped
`src` project XML under TargetRoot and a frozen, minimal policy projection in
PackageRoot. It never discovers `guard/**`, writes to TargetRoot/PackageRoot,
executes head binaries, invokes V3 code or uses the network. Module capability
ceiling: read `TargetRoot`/`PackageRoot`; write none; process `pwsh`; timeout
30 seconds. The rule execution plan selects only
`IFX.L2.2.DIRECT_DOMAIN_CONTRACTS` with a blocking finding, raw-project
evidence and nonzero Domain-project coverage. Full-graph and source-import
parts remain an explicit blocking gap.

Fixtures must cover clean, direct forbidden reference, missing `src`, zero
Domain projects and a reference path that attempts to escape `TargetRoot`.
Tests assert deterministic sorting, exact rule/evidence IDs, no finding on a
same-ring/non-Contracts reference, schema-valid output, source policy hash,
and target byte invariance. Validate the candidate manifest, config/result
schemas and hashed authority/lock against published V4 public contracts. If
the V4 Host/loader requires modification, stop and open the parent's separate
compatibility Plan; do not touch the published or installed 1.1.2 package.

## Acceptance boundary

Run Formal Pre before candidate/mapping edits, then fixture and contract tests,
isolated `ifx-package-test`, unchanged V4 Package hash and exact Formal Diff.
C1b may establish only this subset's candidate behavior. It does not approve
an extension bundle, a production Profile, human review, composition, P10.2
parity or cutover.

Formal Pre passed before the candidate files were written. The candidate
module, its hashed policy, rule plan, dependency lock and result/config
schemas passed the V4 module contract check. Five direct fixtures passed:
clean (including an intentionally excluded `guard/**` violation), two sorted
forbidden references, missing `src`, zero Domain projects and an escaping
reference. Policy-hash drift failed closed and fixture TargetRoot hashes were
unchanged. The module was then composed only as a `synthetic-test-only` fixture
against the receipted, published 1.1.2 installation: composition and receipt
verification passed, and the real V4 Host returned the expected Pre result for
clean, forbidden-reference and zero-Domain cases. Local evidence is under
`artifacts/guards/p10-ifx-c1b/test-runs/24e0fecc419446d697cb3564c353f65f`.
Direct invocation against the current IFX TargetRoot matched five Domain
projects, returned zero findings and did not execute target code. The isolated
IFX package regression passed; local V4 Package validation still returned
`922196c12917436b087c9c09361ca3669103992694eb5aa0ca8f2873ecc11a8d`.
No Linux-complete certification, real IFX bundle review, production Profile or
installed IFX composition is claimed. Full L2.2 direction/import semantics
and the other IFX gates remain open.
