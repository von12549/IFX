# V4 P10.3 successor — standalone V4 Guards 1.1.5 + `ifx_profile` 0.4.3

Status: `DESIGN AND LOCAL REHEARSAL — V4-TODO-008 T7; REMOTE ACTIVATION NOT AUTHORIZED`

Formal Plan: `20260928-v4-todo-008-t7-ifx-consumer-rebinding`.

This successor rebinds the accepted P10.3 design (`09-p10-3-cutover-and-rollback-proposal.md`, decision
`529e19b5…`) from the IFX-incubated V4 Guards 1.1.4 to the standalone release published from
[`von12549/Guard`](https://github.com/von12549/Guard). The 1.1.4 + 0.4.2 decisions stay historical facts
and are not edited. The design rules — coexistence, ownership, bridge, rollback order — are unchanged;
only the bound identities and the release source change.

## Bound baseline

| Item | Value |
| --- | --- |
| V4 release | `v4-guards-v1.1.5` from `von12549/Guard`, commit `a02ee3c66712c1cc9c3a84676da8ce1cd1bd6286` |
| Archive | `v4-guards-1.1.5.zip`, SHA-256 `74c371ebca73186d5ef636669a226960982c5c28b13532bc5972cbcdffee3976` (pinned; the GitHub release is not marked immutable) |
| IFX bundle | `ifx-profile-candidate` 0.4.3, manifest `24c325acfe42723f9683b7da73a9dc61abac3e738711657841fa483ae56fdc03`, Profile `a8558812…` |
| Production review | `7619c12e…` (human review by `xiaolong-feng`, R4 decision `074266b1…`) |
| Composed Package | `25fd95fa4f8e56190aa5993ddc7efde99c3aafd8a185fbb7cdaead8efa1369c6`, receipt `6901c54f…` |
| IFX Target commit | `1fcc07838c4c37a2ee8518a27f8966f8f5a095f5` (T7 R3 harness commit, Plan Amendment A1) |

The identity file `docs/guards/candidates/ifx-rebind-115/t7-identity.json` binds every record below.

## Evidence

| Step | Result | Record |
| --- | --- | --- |
| R3 C6c | Windows product certification and controls pass: 37 suites, 191/191 core cases. Linux is a visible non-blocking `advisory-fail` (C6c22) | `artifacts/guards/p10-ifx-115/c6c-decision.json` `8ef606c2…` |
| R4 review | Exact 0.4.3 packet accepted. Differences from 0.4.2: only `profile.json`, `authority-map.json`, `evidence-lineage.json` and the manifest; module declarations and ceilings identical | `c6d-review-043/c6d-decision.json` `074266b1…` |
| R5 composition | Production composition verified; installed-Host Pre: clean pass (10 modules, 22 non-vacuous claims), deliberate `T7R5Fault.cs` blocks with `IMPORT-DIRECTION` from `ifx-source-policy`; Host queries agree; protected roots unchanged | `r5-043/r5-decision.json` `b9916376…` |
| R6 parity | 52/52 cases, zero gaps, the same 15 visible fail-closed strengthenings; semantically identical to the accepted 1.1.4 R2 row by row | `p10-2-parity-043/p10-2-decision.json` `443ffdfe…` |
| R7 rehearsal | Accepted design rules re-proved on the successor proposal and specimen; seven executed negative controls rejected | `p10-3-successor-043/rehearsal/p10-3-successor-decision.json` |

The V3/V3_ifx reference inventory at the Target commit differs from the accepted one only in
`docs/guards/V3_ifx/shared/policy-config.json` (the O5 registration fix); the V3 policy and trusted
components are byte-identical.

### Linux advisory change

The 0.4.2 Linux run passed direct-post and dependency-post and stopped later at the tracked-source-clean
matrix precondition. The 0.4.3 Linux direct-post fails earlier: `ifx-database-evidence` exceeds its declared
60 s timeout. An isolated diagnostic in the same pinned container reproduced it 3/3; the adapter alone
passes but needs 73–85 s over the Windows bind mount. The workload (1152 source files) and the module bytes
are identical to 0.4.2. This is a portability margin, not a content change. It does not change the design:
`v3-cross-platform-ubuntu-latest` already stays required as the Linux compatibility bridge. A later bundle
version may raise or platform-scale that timeout under its own Plan.

## Successor specimen and proposal

`integrations/github/proposed-v4-ifx-guardrails.yml` and `integrations/github/ifx-cutover-proposal.json`:

- fetch V4 only with `gh release download v4-guards-v1.1.5 --repo von12549/Guard` and verify the archive
  SHA-256; `${{ github.repository }}` is no longer used;
- read the future IFX bundle from `docs/guards/v4-adoption/extensions/ifx/0.4.3`, never from `docs/guards/v4`;
- evaluate the aggregate from the previously trusted base with
  `docs/guards/candidates/ifx-rebind-115/Test-IFX115CutoverRollback.ps1`;
- bind the rollback anchor to the current remote development-branch commit and V3 workflow blob from a
  GET-only snapshot.

## Negative controls executed by the rehearsal

| Control | Mutation | Expected |
| --- | --- | --- |
| `wrong-release-repository` | download from `${{ github.repository }}` | rejected |
| `missing-release-asset` | asset name not present in the live Guard release | rejected |
| `archive-hash-drift` | pinned archive SHA-256 changed | rejected |
| `missing-bundle` | unpublished-bundle refusal removed | rejected |
| `source-path-fallback` | bundle path under `docs/guards/v4/` | rejected |
| `candidate-self-judgment` | aggregate run from the candidate checkout | rejected |
| `premature-cleanup` | `ifxCoreSourceRemoved = true` before T8 | rejected |

## Activation blockers retained

Unchanged from P10.3, with the bundle version updated: default-branch promotion, publication of the exact
0.4.3 bundle, installing and negative-testing the specimen, adding `v4-ifx-required` to the ruleset and the
coexistence window each need their own exact Plan and authorization. P10.GATE, cutover and V3 retirement
stay false. The installed Web UI hands-on record for 1.1.5 + 0.4.3 is left to the P10.GATE successor.
