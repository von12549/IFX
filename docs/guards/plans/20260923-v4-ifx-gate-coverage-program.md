# V4 P10.1 — IFX remaining-gate coverage program

Status: `AUTHORIZED PROGRAM — C0 inventory complete; implementation tranches pending`

On 2026-09-23 the user authorized a separate project to complete the IFX gates
left out of the source-bound `ifx-profile-candidate` 0.2.0 draft. This Plan opens
that project; it does not mark any missing gate implemented, accept bundle bytes,
compose an operational IFX installation, perform P10.2 parity or authorize cutover.

## Fixed entry point

The public V4 base is now `v4-guards-v1.1.2`, source commit
`5bc176f61508fd01ddceb2d4e33ee34136493a35`, Package hash
`922196c12917436b087c9c09361ca3669103992694eb5aa0ca8f2873ecc11a8d`,
release ZIP SHA-256
`12270a26f923a86f49be4ee0d003f5493b2562891fd1484a4fac079f02b73c95`.
Its receipted sibling installation is outside the IFX TargetRoot. The published
base does **not** include `ifx_profile`. The 0.2.0 draft remains historical: its
authority map binds the earlier local candidate archive, so it cannot be approved
or composed unchanged against the published release.

Current demonstrable coverage is only scoped, resolved project-reference
completeness under `src` and `tests`: the real IFX TargetRoot matched 80 projects
with zero findings. This result does not establish any other IFX claim. The eight
source hashes and the partial/missing mapping states in the 0.2.0 authority map
are the starting inventory, not a declaration that only eight artifacts matter.
The active V3/V3_ifx guard remains the independent reference throughout P10.1.

C0's exact inventory found 13 declared V3_ifx Stage gates: ten Post gates are
the direct P10.1 coverage target, while one Diff gate and two CI gates require
an explicit P10.3 trusted-base/workflow transition. The machine-readable
source and gap matrix is `docs/guards/inventories/20260923-ifx-v3-gate-inventory.json`.
In particular, the older 0.2.0 draft's eight authority anchors did not cover
Plan04, Database, the three Quality gates or Historical Integrity.

## Ordered workstreams and stop gates

| Workstream | Required output | Fail-closed proof before closure |
| --- | --- | --- |
| C0 — exact inventory | Enumerate every current IFX rule/claim, detector family, authority file, Stage, command, prerequisite and waiver; freeze source hashes, owners, rule IDs and expected evidence kinds. Reconcile against the eight draft anchors and identify additional authorities. | Every V3_ifx obligation has one explicit V4 destination or a recorded blocking gap; no silent omission or inferred equivalence. |
| C1 — project, toolchain and architecture | Map project-area ownership and toolchain commands/prerequisites. Translate the remaining ring, reference, package, namespace, declaration, forbidden-symbol, payload and compiled-assembly claims to V4 built-in configuration or new reviewed modules. | Clean, violating, missing-input and zero-match fixtures per detector family; exact scope and non-vacuous coverage, with no `guard/**` subject discovery. |
| C2 — G03 governance | Implement a declared module for governance ownership, contracts/providers/adapters, policy hashes and waiver handling using the V3 policy as facts, not V3 runtime code. | New/stale/missing governance evidence blocks; each active subclaim has targeted negative and zero-match controls. |
| C3 — G04 runtime manifest | Implement a declared module for release/runtime manifest, deployment inventory, required bindings and schema compatibility. | Missing, stale, contradictory and malformed manifest or deployment evidence blocks; clean fixture binds exact release inputs. |
| C4 — G05 context protocol | Implement a declared module for context/event identifiers, envelopes and boundary/dependency policy. | Deliberate protocol/boundary violations, missing evidence and zero-match cases block. |
| C4a — Plan04 governance | Map projection, extraction, tenant-query and exception-registry obligations to a reviewed module and immutable authority inputs. | Missing, stale or inconsistent governance/exception evidence blocks; no bypass is silently inherited. |
| C4b — Database safety | Map migration/release manifests and safety policy, including exact command capabilities and fresh evidence requirements, to a reviewed module or a separately authorized compatibility change. | Missing/invalid migration evidence blocks; execution scope and external effects are bounded and tested. |
| C5 — Quality, Historical Integrity, baseline and Stage integration | Cover solution, compiled assembly and frontend quality gates plus historical-integrity checks; translate only individually reviewed waivers to explicit Profile-owned baselines; assign Bootstrap, Analysis, Pre and Post ownership and dependencies. | Fresh toolchain/build evidence, all 15 historical entries, direct/dependency Stage runs, stale/unused waiver and zero-match controls retain blocking categories, authority hashes and immutable roots. |
| C5g — Diff/CI governance classification | Track `v3-pre-diff` and both cross-platform CI gates as P10.3-deferred rather than claiming them as P10.1 runtime coverage. | Separate trusted-base, workflow and required-check transition Plan before activation; no silent retirement of V3 checks. |
| C6 — final bundle and operator practice | Create a new draft version bound to the **published** 1.1.2 base (or to a separately published later patch if C1–C5 require core changes). Freeze manifest, full ordinal inventory, module locks/capability ceilings and review bytes. | Windows-full and pinned offline Linux-complete, independent clean/violation matrix, accepted human-review record by Xiaolong Feng over exact final bytes, new receipted composition, then installed Web UI practice. |

Each workstream begins with an exact child formal Plan and `plannedPaths`, a
source-authority/claim matrix and Formal Pre **before** editing runtime or bundle
bytes. C0 may discover additional IFX authorities; update the mapping explicitly
before C1–C5 implementation. Keep new executable modules within V4's public
extension contract: registry/manifest, schemas, dependency locks, declared Stage,
capabilities and deterministic result evidence. Default-deny capabilities; H1=A,
H2=A, H3=A and H4=A remain the previously confirmed compatibility decisions.
Neither those decisions nor naming Xiaolong Feng approves an actual bundle.

If any claim requires Host, schema, loader, installer or built-in module changes,
stop that tranche and open a separate exact V4 compatibility Plan and unique
`1.1.x` patch with full dual-platform certification and publication authority.
Do not patch the installed 1.1.2 tree or import V3 runtime paths into V4.

## Acceptance matrix and handoff

For every mapped claim and specialized gate, record the source authority hash,
V4 module/config/baseline hash, owning Stage, detector ID, evidence kind,
minimum-match threshold, clean/violation/missing/zero-match fixtures, expected
blocking category and actual result. Require fresh build evidence where compiled
claims need it. A missing detector, weakened severity, vacuous success, unreviewed
waiver, stale evidence or unexplained V3/V4 divergence is a blocker, not a passed
baseline. TargetRoot and PackageRoot must remain byte-invariant; StateRoot and
EvidenceRoot are the only mutable runtime roots.

C6 closes P10.1 only after final bundle review, composition and the prescribed
installed Web UI exercise. P10.2 then uses a separately frozen IFX commit and
corpus for independent V3/V4 parity; this program cannot self-declare parity.
Workflow/ruleset activation, V3 retirement, IFX cutover and any destructive
uninstall remain outside this authorization.

## This planning checkpoint

Only this Plan pair is changed. Formal Pre and exact Diff must accept the two
declared documentation paths. The published 1.1.2 tag, Release, installed bytes,
external receipts and V4 package hash remain unchanged. Run the declared isolated
`ifx-package-test` and verify the local V4 Package check. The next actionable step
is C0's exact source/claim inventory and a child Plan for the first bounded
implementation tranche; do not treat this program document as an executable
change authorization for unspecified paths.

Formal Pre passed for the exact two-path Plan. The isolated `ifx-package-test`
passed its positive and negative cases, and the local V4 Package check returned
the published Package hash above. These checks validate this planning checkpoint,
not the still-missing IFX gate implementations.
