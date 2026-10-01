# IFX I2-D — publish the curated `v4-adoption` package and the exact 0.5.2 bundle to `main`

Status: `ACTIVE — rulings RD1–RD6 taken as recommended and D0–D5 authorized for local execution (2026-10-01, "全部按推荐，并授权D0到D5本地执行"); D0–D5 complete (D5 accepted, "接受，授权 D6"); D6 done (PR #114); D7–D9 authorized ("#114 CI已通过。授权D7/8/9"); COMPLETE (2026-10-01): main `d2ddb2b4`, receipt `v4-adoption/migration/ifx-i2d-publish-receipt.json`; D9 pushes the development branch`

Formal Plan ID: `20261001-v4-ifx-i2d-publish-trusted-inputs`. Phase I2-D of the program Plan
`20260929-v4-ifx-i2-p10-gate-successor`. I2-E (installing the workflow) builds on it.

## 1. Purpose

The V4 workflow specimen reads its trusted inputs from the pull request **base**. On `main` these inputs must be the
exact, reviewed bytes:

- the 0.5.2 bundle and its production review, under `docs/guards/v4-adoption/extensions/ifx/0.5.2`;
- the staging script and the aggregate (`ci/`), which run from the trusted base;
- the evidence producers (`producers/`), which run from the Target and are pinned by the lock consumers.

Today `main` holds only `docs/guards/v4-adoption/README.md`, the entry that I2-C admitted. I2-D publishes the curated
package through one V3-judged pull request and proves that the published bytes are exactly the certified ones. It
does not install a workflow, change the ruleset or activate anything.

## 2. Read-only facts (2026-10-01)

**Remote state.**
- `main` = `codex/guards-principles-plan` = `7b9b53dc`; the default branch is `main`.
- Ruleset 23459908 is unchanged since I2-C (13 contexts, `strict`, no bypass).
- The development branch is `0b38f0f3`; A3 is complete.

**What the specimen expects** (`integrations/github/proposed-v4-ifx-guardrails.yml`):
- `$IFX_BUNDLE_BASE_PATH/bundle/bundle-manifest.json`, hash `a2f619a3…`;
- `$IFX_BUNDLE_BASE_PATH/production-extension-review.json`, hash `38eb775a…`;
- `ci/Invoke-IFXEvidenceProducers.ps1` and `ci/Invoke-IFXV4Aggregate.ps1` from the trusted base;
- the six producers under `producers/` in the Target.

If the manifest or the review is missing, the specimen refuses to continue: "The exact IFX bundle has not been
published into the trusted base by its separate authorization."

**The bundle's bytes.** The certified bundle (`a3-052/formal-candidate-a/8f06b1c7…/bundle`) has 263 files: 227 JSON and
36 PowerShell. All are text with LF line endings, and there are no binaries or CR bytes. `docs/guards/** text eol=lf`
therefore checks every file out byte-identical on Windows and Linux, including with `core.autocrlf=true`, which hosted
Windows runners use.

**What V3 checks.**
- `docs/guards/v4-adoption` is not a V3 protected path (`stages/diff/protection.json`), so adding files raises no
  protected-change obligation. The admission decision `20261001-v4-ifx-i2c-v4-adoption-admission` covers
  `docs/guards/v4-adoption/**` for the `guard-rules` risk.
- `Test-CutoverPreservation` already admits the entry.
- No V3 check scans the content of `docs/guards` beyond its top level; the tool analysis excludes `docs/guards/**`.

**The development branch `v4-adoption`** (45 files):
- `producers/` (23 files, with `origins.json`) and `ci/` (2);
- `integrations/github/`: the specimen and the proposal;
- `migration/`: 7 receipts;
- `plans/`: 10 design notes;
- the development edition of `README.md`.

The bundle and its review exist only as records under `artifacts/`; they are not yet under `v4-adoption`.

## 3. Operator rulings needed

| Ruling | Question | Options | Recommendation |
| --- | --- | --- | --- |
| **RD1** | What `main` receives | (a) the 2B set: `extensions/ifx/0.5.2/` (bundle and review), `producers/`, `ci/`, `integrations/github/`, `migration/`, plus a `main` edition of the README; (b) only the runtime inputs (bundle, review, producers, `ci/`); (c) everything, design notes included | **(a)**, the set decision 2B named. The design notes stay on the development branch and are referenced by commit; they cite lab records that `main` does not hold |
| **RD2** | How many pull requests | (a) one atomic PR; (b) one PR per directory | **(a)**. A partial publication would leave a base whose bundle and producers do not match, and V3 sees no protected obligations to split |
| **RD3** | `docs/guards/TODO.md` | (a) stays on the development branch until P10.GATE; (b) moves to `v4-adoption/TODO.md` now | **(a)**. Its entries cite lab records; the `main` README points to it on the development branch (RC6 left this to I2-D) |
| **RD4** | Protection of the published inputs on `main` | (a) defer: a separate V3 trust change (`protection.json`, two-PR flow) before I2-F; (b) include it in I2-D | **(a)**. The workflow reads every input from the pull request base and the consumers pin every producer, so a pull request cannot judge itself. Deletion protection only matters once `v4-ifx-required` is required (I2-F) |
| **RD5** | The bundle on the development branch | (a) add `extensions/ifx/0.5.2/` there first (byte copy from the certified bundle), then publish from that commit; (b) publish to `main` only and merge back | **(a)**. Every published file then has a development-branch source blob, and the merge back conflicts only on the README |
| **RD6** | Merge method | merge commit (as RC5) | **Merge commit** |

Rulings (2026-10-01): **RD1 (a)** the 2B set plus a `main` README; **RD2 (a)** one atomic PR; **RD3 (a)** `TODO.md` stays
on the development branch; **RD4 (a)** protection deferred to a V3 trust change before I2-F; **RD5 (a)** the bundle is
added to the development branch first; **RD6** merge commit.

## 4. Steps

Local steps are D0–D5. From D6 on, **each step is a separate authorization**, and a push and a merge are two separate
authorizations. Evidence: `D:/IFX-Root/v4-todo-008-evidence/I2D-publish` (`evrun.py --ev I2D-publish`); records under
`artifacts/guards/p10-ifx-i2d/`.

| Step | Action | Kind |
| --- | --- | --- |
| D0 | Commit this Plan pair after `plan validate`. Correct the stale A3 texts: the I2-B status line, §11 status and §11.7 still say "A3-12 needs authorization"; the TODO entry | Local |
| D1 | GET-only remote snapshot: the three branch heads, the default branch, the canonical ruleset SHA-256 (must equal I2-C's `857a51aa…`), open pull requests. Record `d1-remote-snapshot.json` | Local, GET |
| D2 | RD5: copy the certified bundle and the production review byte for byte into `docs/guards/v4-adoption/extensions/ifx/0.5.2/` on the development branch, in its own commit. Every file must equal its manifest hash, the manifest `a2f619a3…`, the review `38eb775a…`; the Git blobs must match on a re-checkout | Local commit |
| D3 | Prepare the PR head with `candidates/ifx-i2d/` (the I2-C head builder with its own spec), in a disposable clone at `main`:<br>• copy every RD1 path from the D2 commit;<br>• add the authored `main` README and a V3-format plan pair;<br>• require every copied blob to equal its development-branch blob | Local |
| D4 | **Rehearsal** in a clone outside the repository, with `main`'s own trusted runner. V3 checks: trusted Diff (no protected obligation expected), Validate, candidate package tests (including `Test-CutoverPreservation`), Architecture, Historical Integrity, G03.<br>**Publication proof** on fresh clones of the PR head, with `core.autocrlf` both `true` and `false`:<br>• the specimen's own input checks pass (manifest and review hashes);<br>• every bundle file matches its manifest entry;<br>• a local composition of the published bundle with the 1.1.6 base gives the A3-10a package hash `0fab0676…`;<br>• no published path lies outside `docs/guards/v4-adoption`.<br>Record `d4-rehearsal/` | Local |
| D5 | Operator review of the prepared diff and the rehearsal; decision `d5-decision.json`; commit | Local, **operator** |
| D6 | Push branch `codex/i2d-publish-v4-adoption` and open the PR to `main`. The operator reports the checks, or asks for a single GET read; nothing polls | **Remote** |
| D7 | Merge with a merge commit after all 13 contexts pass, with `--match-head-commit` | **Remote** |
| D8 | Post-state `d8-post-state.json`:<br>• `main`'s `v4-adoption` equals the PR head byte for byte;<br>• one GET read of the push-triggered V3 run;<br>• merge `origin/main` into the development branch (one expected conflict: the README keeps the development edition);<br>• receipt `v4-adoption/migration/ifx-i2d-publish-receipt.json`; TODO and program Plan updated; commit | Local, GET |
| D9 | Push the development branch (fast-forward) | **Remote** |

## 5. Acceptance

- Every remote step was authorized on its own. There was no force push, no `--admin`, no ruleset or bypass change, and
  the ruleset still equals I2-C's snapshot.
- The PR's final head passed all 13 contexts, with no protected-change obligation.
- On `main`, `docs/guards/v4-adoption` holds exactly the RD1 set:
  - every file equals its development-branch source blob, and the README is the authored `main` edition;
  - the bundle equals the certified 0.5.2 bundle file by file (manifest `a2f619a3…`), and the review is `38eb775a…`;
  - a composition of the published bundle gives the package `0fab0676…`.
- The specimen's input checks pass on Windows-style (`autocrlf=true`) and Linux-style checkouts of `main`.
- No workflow is installed, nothing is activated, and P10.GATE, cutover and V3 retirement stay false.

## 6. Stop conditions

Each of these stops I2-D, and the evidence is kept:

- the D1 snapshot differs from §2, or `main` moves unexpectedly;
- any published file differs from its source, or a hash, the manifest or the composed package does not match;
- a V3 check derives a protected obligation, or a required context fails for any reason other than a content defect of
  the pull request (runner drift or a false failure needs its own Plan; a break-glass is the operator's decision);
- anything would need a force push, `--admin`, a ruleset, bypass or V3 workflow change.

## 7. Rollback

- Before D7: close the PR.
- After D7: a V3-judged revert pull request removes the published files. `v4-adoption` is not a protected path, so no
  authorization is needed. Nothing on `main` reads the package until I2-E installs the workflow.

## 8. Planned paths

- `docs/guards/plans/20261001-v4-ifx-i2d-publish-trusted-inputs.md` and `.plan.json`
- `docs/guards/plans/` V3-format plan pair of the publication PR (`2026MMDD-v4-ifx-i2d-*`)
- `docs/guards/candidates/ifx-i2d`
- `artifacts/guards/p10-ifx-i2d`
- `docs/guards/v4-adoption/extensions/ifx/0.5.2/**` (new on both branches), `docs/guards/v4-adoption/README.md`,
  `docs/guards/v4-adoption/migration/ifx-i2d-publish-receipt.json`
- on `main` only, by copy: `docs/guards/v4-adoption/{producers,ci,integrations,migration}/**`
- `docs/guards/TODO.md`, `docs/guards/plans/20260929-v4-ifx-i2-p10-gate-successor.md`,
  `docs/guards/plans/20260929-v4-ifx-i2b-ci-evidence-and-bundle.md`

## 9. Out of scope

- Installing the workflow as `.github/workflows/v4-ifx-guardrails.yml` and its remote negative tests (I2-E), including
  the producers' runtime prerequisites on the hosted runner (.NET SDK `10.0.303`, SQL Server).
- The ruleset (I2-F), the coexistence window and P10.GATE (I2-G).
- V3 protection of `v4-adoption` (RD4), V3 retirement (I3) and Guard product changes.

## 10. Progress

- **D0 (2026-10-01).** Rulings RD1–RD6 taken as recommended; D0–D5 authorized for local execution. The stale A3 texts of
  the I2-B Plan and the TODO are corrected.
- **D1.** GET-only snapshot passes (`d1-remote-snapshot.json`, evrun 001): `main` = `codex/guards-principles-plan` =
  `7b9b53dc`, default branch `main`, `main`'s `v4-adoption` only the README, ruleset equal to I2-C (`857a51aa…`), no open
  pull request.
- **D2 (`2c82d6e8`).** `docs/guards/v4-adoption/extensions/ifx/0.5.2/` on the development branch: the bundle (manifest
  `a2f619a3…` plus 262 package files, each equal to its manifest entry) and the review `38eb775a…`; Git stores every file
  without normalization (`Copy-IFXI2DBundle.ps1`, evrun 002-003).
- **D3 (`4fe202f1`).** `candidates/ifx-i2d/pr-spec.json`: 298 files copied from `2c82d6e8`, the `main` README and a V3 plan
  pair listing all 301 paths (V3 Diff matches paths exactly); the I2-C head builder reused as a byte copy.
- **D4.** Rehearsal passes (evrun 005, `d4-rehearsal/rehearsal.json` `0704f14d…`):
  - on `main`'s trusted runner: trusted Diff with no protected obligation, no trusted component change, Validate,
    candidate tests, Architecture, Historical Integrity, G03;
  - on fresh checkouts with `core.autocrlf` true and false: the specimen's input checks, every bundle file against its
    manifest, every published file's bytes against its source, nothing outside `v4-adoption` changed, and
    `Test-CutoverPreservation`;
  - the published bundle, copied out of the checkout as the specimen does, composes to package `0fab0676…` (A3-10a).

  Attempt 1 (evrun 004) passed the 17 V3 and publication checks, but the composer refused a bundle root inside the
  Target checkout; it is kept under `artifacts/guards/p10-ifx-i2d-trials`.
- **D5.** Review packet `d5-review/review-packet.json` `5e2d2211…` and `review.md` (evrun 006). Accepted ("接受，授权 D6"); decision `d5-decision.json`.
- **D6.** `main` still `7b9b53dc`. Head rebuilt on it (`d5218f87`, 301 changes, byte checks pass); the trusted Diff re-run on
  that exact head passes with no protected changes; branch `codex/i2d-publish-v4-adoption` pushed and verified; PR
  [#114](https://github.com/von12549/IFX/pull/114) opened to `main` (`d6-record.json`).
- **D7.** Authorized ("#114 CI已通过。授权D7/8/9"). One GET read: 13/13, CLEAN, head `d5218f87`. Merged with a merge commit
  and `--match-head-commit`: `main` = `d2ddb2b4` (parents `7b9b53dc`, `d5218f87`); its tree equals the PR head.
- **D8.** Post-state passes (`d8-post-state.json`): default branch `main`; `docs/guards` top level `V3`, `V3_ifx`, `plans`,
  `v4-adoption`; the 299 `v4-adoption` files on `main` are exactly the published set, every one equal to its source blob;
  manifest `a2f619a3…`, review `38eb775a…`; ruleset unchanged; no open pull request. The push-triggered V3 run on `main`
  (36865277272) was in progress at the one read and is not polled. `main` merged into the development branch
  (`d2b5472c`): the README conflict keeps the development edition with a note naming the `main` edition; under
  `v4-adoption` only the README and `plans/` differ from `main`. Receipt `v4-adoption/migration/ifx-i2d-publish-receipt.json`.

