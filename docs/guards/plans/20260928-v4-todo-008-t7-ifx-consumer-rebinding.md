# V4-TODO-008 T7 — IFX consumer rebinding to standalone V4 Guards 1.1.5

Status: `APPROVED 2026-09-28 — A-IFX-REBIND local part authorized ("授权A-IFX-REBIND本地部分，执行R0–R3和R5–R9"); R4 and R10 need separate decisions`

Formal Plan ID: `20260928-v4-todo-008-t7-ifx-consumer-rebinding`.

This Plan executes tranche T7 of the master Plan `20260927-v4-todo-008-standalone-repository-extraction`
(§7 T7, handoff "T7/T8 IFX rebinding and cleanup checklist" items 1–6). It makes IFX a consumer of the
standalone product published from `von12549/Guard`. It does not perform T8: `docs/guards/v4` stays in
place, and it becomes a frozen, non-canonical duplicate until T8.

## 1. Frozen identities

| Item | Value |
| --- | --- |
| Old canonical source (A2) | IFX `80f7b6b65fb06897444a6a36c604c42c93c834e4`, `docs/guards/v4` tree `af913836…` (175 paths) |
| Guard repository | `https://github.com/von12549/Guard` (public), `main` under ruleset `v4-main-autonomy` (`G2_V4_AUTONOMOUS`) |
| Guard release | tag `v4-guards-v1.1.5` (tag object `dce9295d…`) → commit `a02ee3c66712c1cc9c3a84676da8ce1cd1bd6286` |
| Release asset | `v4-guards-1.1.5.zip`, 1,120,977 bytes, SHA-256 `74c371ebca73186d5ef636669a226960982c5c28b13532bc5972cbcdffee3976` (API digest and `.sha256` asset agree) |
| Package hash | `e8cd32697709e8ca155b051ddbf731e12b65bad42858eafd92cddb0ee4dbf733` (Guard certification run 36331614650: Linux 33/33, Windows 34/34) |
| Guard default-branch commit at handoff | `b339dbc634a60c4be9f8059f798375df4bedad7a` (re-read at R9; any later commit is recorded, not assumed) |
| Accepted 1.1.4 IFX tuple (historical) | V4 1.1.4 + `ifx_profile` 0.4.2, package `739e2035…`, bundle manifest `82eb0c5d…`, C6e-R1 decision `94a7c01b…`, P10.2-R2 decision `7c5ff243…`, P10.3 decision `529e19b5…` |
| IFX Target commit for re-certification | `40b4c0f85e5d8a63ac5af5c1da80d4d46ba32b82` (unchanged, so the frozen V3/V3_ifx reference results and the 52-case corpus stay valid) |

The accepted 1.1.4 P10 decisions stay historical facts. They are not edited, re-signed or reused as
1.1.5 evidence (master Plan §7 T7).

## 2. Why the IFX bundle needs a successor

`Compose-V4Extension.ps1` refuses a bundle whose `baseVersion` differs from the base product version,
and a production `extension-review` record binds `baseArchiveSha256`. The accepted 0.4.2 bundle
declares `baseVersion: 1.1.4` and its review binds the 1.1.4 archive `dce03714…`. It therefore cannot be
composed with 1.1.5.

T7 builds the successor bundle `ifx-profile-candidate` **0.4.3** with the existing C6 builder at the
same Target commit and base 1.1.5. Expected difference from 0.4.2: only `bundle-manifest.json`,
`profiles/catalog/ifx_profile/profile.json` (version) and `authority-map.json` (embedded base
identity) change; all 36 module trees are byte-identical. Any other difference stops T7 for review.

## 3. Steps

Each step writes evidence to `D:\IFX-Root\v4-todo-008-evidence\T7-rebind\<run-id>` and, where the P10
convention applies, selected decisions to `artifacts/guards/p10-ifx-115/…`. Every output path must be
absent before use; no 1.1.4 path is reused or overwritten.

| Step | Action | Effect |
| --- | --- | --- |
| R0 | Commit this Plan pair on IFX `codex/v4-development-base` after V4-native `plan validate` | Local IFX commit |
| R1 | Download `v4-guards-1.1.5.zip` (1.1 MB) from the Guard release; verify size, SHA-256 against the API digest, the `.sha256` asset and §1; install with the released lifecycle command into `D:/IFX-Root/guard-runtime/releases/v4-guards-1.1.5` with receipt `receipts/v4-guards-1.1.5.install.json`; prove version 1.1.5, API 1.0 and package hash `e8cd3269…` | Download; local install |
| R2 | Structured base diff 1.1.4 → 1.1.5 of the installed trees: CLI, schemas, modules, Profiles, Host/Companion. Expected: only the 7 declared T4 files plus the version bump; binaries differ only by build location (O14). Informational; it does not replace R3–R7 | Evidence only |
| R3 | Parameterized successors of the 1.1.4 C6 chain in `docs/guards/candidates/ifx-rebind-115/` (the accepted `*114*` scripts stay unchanged): module inventory → draft bundle 0.4.3 → contract compatibility → focused qualification → formal candidates A/B (byte-identical) → readiness → single C6c run: Windows product certification and controls must pass; Linux stays a visible non-blocking `advisory-fail` exactly as accepted for 0.4.2 | Local IFX commits (scripts, decision); runtime evidence |
| R4 | **Human review (C6d successor).** Export the exact review packet for 0.4.3 + base archive `74c371eb…` (256-file inventory, 36 module ceilings, C6c outcome, and the 0.4.2 → 0.4.3 file diff). Stop. Only Xiaolong Feng's explicit acceptance of the exact packet hashes permits writing the production review record | **Operator decision** |
| R5 | **Composition (C6e successor).** Compose 1.1.5 + 0.4.3 into `releases/v4-guards-1.1.5-ifx-0.4.3` with its external receipt; public verifier without `AllowSyntheticFixture`; two detached Git worktrees at the Target commit; installed-Host direct Pre: clean passes with ten module results and non-vacuous coverage, the deliberate `C6eR1Fault.cs` violation blocks with `IMPORT-DIRECTION` from `ifx-source-policy`; authority roots and Git facts unchanged | Local install; evidence |
| R6 | **Parity (P10.2 successor).** Replay the R2 runner and independent comparator against the new installation on new paths: 52/52 cases, zero blocking gaps, the same 15 visible fail-closed strengthenings, and every V4 replay semantically equal to its certified 1.1.4 capture | Evidence; local commit |
| R7 | **Adoption moves and P10.3 successor.** `git mv` plans 06–09, `ifx-cutover-proposal.json` and `proposed-v4-ifx-guardrails.yml` to `docs/guards/v4-adoption/` (history preserved). Add a successor design `v4-adoption/plans/10-p10-3-successor-standalone-1-1-5.md` and a successor proposal version bound to 1.1.5/0.4.3. The inactive specimen fetches with `gh release download v4-guards-v1.1.5 --repo von12549/Guard` and verifies `74c371eb…`; it never uses `${{ github.repository }}`. A parameterized successor of `Test-IFXP10CutoverRollback.ps1` re-runs the local state-machine rehearsal and adds negative controls for wrong release repository, missing asset, archive hash drift, missing bundle, source-path fallback to `docs/guards/v4`, candidate self-judgment and premature cleanup | Local IFX commits; evidence |
| R8 | **Handoff decision and receipt.** `docs/guards/v4-adoption/migration/v4-todo-008-ifx-rebinding-receipt.json` binds §1, the R1–R7 decision hashes, the 0.4.3 bundle/review/composition identities and the booleans. Guard becomes the canonical V4 source (master Plan §6 condition 6). `docs/guards/v4/README.md` gets a one-paragraph non-canonical notice pointing to Guard; no other file under `docs/guards/v4` changes | Local IFX commit |
| R9 | **Local verification.** V3_ifx `Validate` passes; V3/V3_ifx trees and `.github/workflows` are byte-identical to `42b666ac`; `git fsck --full --strict`; clean worktree; evidence indexed with `SHA256SUMS` | Evidence |
| R10 | **Remote (separate authorization).** Fast-forward push of `codex/v4-development-base` to IFX `origin` (direct, O15). Guard records PR: checklist T7 and §10a row 3 done, A-IFX-REBIND recorded, migration receipt updated; merged normally under `v4-main-autonomy` | IFX push; Guard PR and merge |

## 4. Acceptance

- The 1.1.5 archive, receipt and package hash match §1, installed from the public Guard release.
- 0.4.3 differs from 0.4.2 only as declared in §2; C6c Windows certification and controls pass.
- Explicit human acceptance binds the 0.4.3 packet, and the production review binds archive `74c371eb…`.
- The composed installation verifies; clean Pre passes; the deliberate violation blocks.
- Parity: 52/52, zero gaps, 15 visible strengthenings, no semantic drift from the 1.1.4 captures.
- The P10.3 successor rehearsal passes, including every negative control in R7.
- The receipt sets `standaloneSourceAccepted=true` and `ifxConsumerRebound=true`. The booleans
  `ifxCoreSourceRemoved`, `v4Activated`, `p10GatePassed` and `v3Retired` stay false.
- All 13 V3 contexts, the V3/V3_ifx source, IFX workflows and rulesets are unchanged.

## 5. Out of scope

- T8 removal of `docs/guards/v4` (A-IFX-DELETE).
- Publishing the IFX bundle as a remote-consumable input, installing the specimen under
  `.github/workflows`, any IFX required-context or ruleset change, P10.GATE, activation, cutover and
  V3 retirement.
- The installed Web UI hands-on record for 1.1.5/0.4.3. It is a P10.GATE requirement (06 §8), not a
  T7 requirement, and is left to the P10.GATE successor.
- Guard product changes. A defect found in 1.1.5 stops T7; the fix is a Guard product Plan and a new
  1.1.x release, never a patch of an installed tree.

## 6. Risks

- **Script hard-coding.** The 1.1.4 C6 scripts pin `1.1.4`/`0.4.2` literals. Successors are
  parameterized copies; the accepted scripts stay unchanged as historical authority.
- **Evidence freshness.** C6 evidence locks expire after 3600 s, and the C6c run requires at least
  2700 s of remaining validity. A late start is rerun on new paths, never extended.
- **V3 CI.** The new top-level `docs/guards/v4-adoption` is another path that the candidate V3
  `Test-CutoverPreservation` rejects on PRs. This is already classified by O15 (direct commits).
- **Release immutability.** The GitHub release reports `isImmutable: false`. IFX therefore pins the
  archive SHA-256 as well as the tag; the tag alone is never trusted.

## 7. Stop conditions

Stop on any §1 identity drift, an existing output path, a 0.4.3 difference outside §2, a C6c Windows
or controls failure, a missing or non-exact human acceptance, a composition or verifier failure, a
clean-run failure or missing deliberate finding, any parity gap or semantic drift, a failed rehearsal
or negative control, a V3/workflow/ruleset change, a protected-root mutation, or any need for a remote
write before R10. A stopped result is evidence; the repair needs its own Plan and new absent paths.

## 8. Rollback

Before R10: abandon the local IFX commits and the new runtime directories; IFX `origin`, Guard and all
installations used by the 1.1.4 records are untouched. After R10: revert the exact T7 commits on the
IFX development branch through a reviewed commit; the 1.1.4 tuple and `docs/guards/v4` are still
present because T8 has not run.

## 9. Authorizations requested

- **A-IFX-REBIND (local):** R0–R3 and R5–R9, including the R1 asset download and the local IFX
  commits on `codex/v4-development-base`.
- **R4:** your explicit acceptance of the exact 0.4.3 review packet, requested when it is ready.
- **R10:** IFX push and the Guard records PR, requested after R9.
