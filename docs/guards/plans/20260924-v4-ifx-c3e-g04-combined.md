# V4 P10.1 C3e — G04 combined candidate on 1.1.3

Status: `CANDIDATE VERIFIED — no production acceptance`

Combine the three reviewed G04 candidates from C3b/C3c/C3d in one
candidate-test-only Post Profile on the immutable, receipted V4 1.1.3 base.
Lock all 15 blocking claims, module and policy bytes, current TargetRoot
authority hashes and no baselines. Exercise direct Post and
`--with-dependencies` on real IFX, violating/missing/stale/zero-subject
controls, synthetic-only composition and immutable TargetRoot/PackageRoot.

Freshly replay V3 G04 Phase 12 and Plan02-C1 inbound. Preserve the V3
`PRE-READY` result and seven blockers, three C3d CI checks deferred to
P10.3, the release-manifest/current-csproj digest discrepancy and the
V3 `AddMessaging()` vacuous order predicate as explicit comparison limits.
Do not infer semantic parity, production Profile acceptance, final bundle
review, cutover or G04 closure from a clean combined candidate.

Formal Pre must precede candidate edits; exact Formal Diff, isolated IFX
package regression and receipted 1.1.3 identity complete this tranche.

## Verification record

Formal Pre passed before candidate edits at
`artifacts/guards/p10-ifx-c3e/formal-pre`. The schema-valid three-module
Profile locked 15 unique blocking claims, 79 active mapped checks, three
P10.3-deferred checks and no baselines. Five Host cases (real direct Post,
real dependency-enabled Post, stale authority, missing authority and zero
G04 blockers), four Profile rejection controls and fresh V3 Phase 12/inbound
replay passed at
`artifacts/guards/p10-ifx-c3e/test-runs/8e13f9bb25e64dedba502048527a35f3`.
The V3 replay returned 70/12 passing checks but G04 stayed `PRE-READY` with
seven named blockers and no approval. The published 1.1.3 archive, receipt
and Package hash matched their locked identities; synthetic composition
and TargetRoot/PackageRoot byte invariants passed. The isolated IFX package
regression passed at
`artifacts/guards/v3-ifx-package-test-5102223d032b4b1dae6fb4929fc8b288`.
The frozen release digest/current csproj discrepancy and vacuous V3
`AddMessaging()` predicate remain recorded comparison limits, not parity
claims. Exact Formal Diff is pending the candidate commit.
