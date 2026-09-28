# V4 P10.3 successor — V4 Guards 1.1.6 + `ifx_profile` 0.4.4

Status: `DESIGN AND LOCAL REHEARSAL — IFX I1; REMOTE ACTIVATION NOT AUTHORIZED`

Formal Plan: `20260928-v4-ifx-i1-rebind-1-1-6`.

This successor rebinds the T7 successor design (`10-p10-3-successor-standalone-1-1-5.md`, rehearsal decision
`f9775c58…` as re-run after T8) from V4 Guards 1.1.5 + 0.4.3 to V4 Guards 1.1.6 + 0.4.4. The design rules
are unchanged: coexistence, ownership, the Linux bridge and the rollback order. Only the bound identities, the
harness successors and one added negative control change. The earlier decisions stay historical.

## Bound baseline

| Item | Value |
| --- | --- |
| V4 release | `v4-guards-v1.1.6` from `von12549/Guard`, commit `960678fd1a193d87d5c499f08e79e7ce0550d96a` |
| Archive | `v4-guards-1.1.6.zip`, SHA-256 `92f1ec54db83de24c9d2096c8da5831b0a50bba0d53b9a4c719ad741f1b392c8` (pinned) |
| IFX bundle | `ifx-profile-candidate` 0.4.4, manifest `f71b47543252104370330d4c2ca68cc059a8d1279a7bb1f662361ab6584a64b7`, Profile `4450011a…` |
| Production review | `8e4ee603…` (human review by `xiaolong-feng`, S6 decision `683ca388…`, packet `631e9949…`) |
| Composed Package | `bea54366341289bda0d82dd9bfb9c0653864ff614ebc9ddebbeda47ff090d37a`, receipt `a75e67bc…` |
| IFX Target commit | `44536a6a2738004cfae5645f1d2d1206679d9b5d` (the S5 harness commit) |

The identity file `docs/guards/candidates/ifx-rebind-116/i1-identity.json` binds every record below.

## Evidence

| Step | Result | Record |
| --- | --- | --- |
| S5 C6c | Windows product certification and controls pass (191/191). **Linux passes too** (191/191, semantic projection equal to Windows) — the first full Linux matrix pass of the IFX C6c | `artifacts/guards/p10-ifx-116/c6c-decision.json` `504968ff…` |
| S6 review | Exact 0.4.4 packet accepted. Differences from 0.4.3: only `profile.json`, `authority-map.json`, `evidence-lineage.json` and the manifest; module declarations and ceilings identical | `c6d-review-044/c6d-decision.json` `683ca388…` |
| S7 composition | Production composition verified. Installed-Host Pre passes on the clean Target with non-vacuous coverage; the deliberate `I1S7Fault.cs` blocks with `IMPORT-DIRECTION`. Host queries agree; protected roots unchanged | `s7-044/s7-decision.json` `77acf8ad…` |
| S8 parity | 52/52 cases, zero gaps, the same 15 fail-closed strengthenings. Semantically identical row by row to the T7 0.4.3 and the 1.1.4 R2 matrices | `p10-2-parity-044/p10-2-decision.json` `59936476…` |
| S9 rehearsal | Design rules re-proved on the successor proposal and specimen; eight negative controls rejected | `p10-3-successor-044/rehearsal/p10-3-successor-decision.json` `b5882ec7…` |

The V3/V3_ifx reference inventory at the Target commit equals the accepted T7 inventory `c910ec9c…`.

### Linux portability, now passing

T7 recorded Linux as a non-blocking `advisory-fail`. Three harness causes are fixed in the I1 successors
under `docs/guards/candidates/ifx-rebind-116/`. The product modules are unchanged.

- **IFX-V4-002**: `ifx-database-evidence` timed out only because the Target was read over the Docker
  Desktop 9p mount. On container-native storage the adapter needs 1.2–1.7 s against its 60 s budget, and
  over the mount 58.7–69.3 s. The C6c Linux leg now keeps its Target, work and matrix paths on `/native`.
- **IFX-V4-003**: the Linux installer now comes from the hash-verified release archive, not from the
  removed `docs/guards/v4`.
- **IFX-V4-004**: the accepted matrix inputs also read the removed copy under upper-case `docs/guards/V4/`.
  - The module and Profile schemas and the built-in adapter now come from the verified base, pinned to the
    removed files' hashes.
  - The provenance suite is a pinned Git blob.

Amendment A5 also re-records the index of the byte-copied Linux checkout, with content equality enforced.
The independent matrix's tracked-source-clean precondition now holds; it had stopped the Linux matrix
since 0.4.2.

The Linux leg stays non-blocking under C6c22. Making it blocking, and removing the
`v3-cross-platform-ubuntu-latest` bridge, are P10.GATE decisions.

## Successor specimen and proposal

`integrations/github/proposed-v4-ifx-guardrails.yml` and `integrations/github/ifx-cutover-proposal.json`:

- fetch V4 only with `gh release download v4-guards-v1.1.6 --repo von12549/Guard` and verify `92f1ec54…`;
- read the future IFX bundle from `docs/guards/v4-adoption/extensions/ifx/0.4.4`;
- evaluate the aggregate from the previously trusted base with
  `docs/guards/candidates/ifx-rebind-116/Test-IFX116CutoverRollback.ps1`;
- bind the rollback anchor to the remote development-branch commit `2141f040…` and V3 workflow blob
  `51986b5a…` from a GET-only snapshot.

## Negative controls executed by the rehearsal

The seven T7 controls (`wrong-release-repository`, `missing-release-asset`, `archive-hash-drift`,
`missing-bundle`, `source-path-fallback`, `candidate-self-judgment`, `premature-cleanup`), plus:

| Control | Mutation | Expected |
| --- | --- | --- |
| `installer-from-target-source` | the specimen installs V4 from the checkout's `docs/guards/V4/…` instead of the verified archive | rejected (the removed-path check is case-insensitive) |

## Activation blockers retained

These are unchanged, with the bundle version updated. Each of the following needs its own exact Plan
and authorization:

- default-branch promotion;
- publication of the exact 0.4.4 bundle;
- installing and negative-testing the specimen;
- adding `v4-ifx-required` to the ruleset;
- the coexistence window.

P10.GATE, cutover and V3 retirement stay false. The installed Web UI hands-on record for 1.1.6 + 0.4.4 is
left to the P10.GATE successor (IFX-V4-001, I2).
