# IFX I2-C — promote to `main` and admit `docs/guards/v4-adoption` (decisions 1A and 2B)

Status: `ACTIVE — rulings RC1–RC6 taken as recommended and C0–C4 authorized for local execution (2026-10-01, "全部按推荐，并授权C0到C4本地执行"); C0–C3 complete; C4 accepted and C5 authorized ("接受，授权 C5"); C5 done (#109 merged `218591ec`); C6 authorized ("授权合并 #109，并授权 C6"): #110 merged `4a787504`; P2 PR #111 open; every remote step C5–C12 needs its own authorization`

Formal Plan ID: `20261001-v4-ifx-i2c-main-promotion`. Phase I2-C of the program Plan
`20260929-v4-ifx-i2-p10-gate-successor`. Phases I2-D to I2-G build on it.

## 1. Purpose

I2-D publishes the exact bundle into the trusted base on `main`. Before that can happen, two things must be true:

1. `main` must hold the V3-protected history (decision **1A**).
2. V3's required checks must accept a `docs/guards/v4-adoption` entry on `main` (decision **2B**).

I2-C does both. It also brings the non-lab changes of the development branch to `main` through V3-judged pull
requests: the IFX-V4-005 product fix and the six G03 governance changes. It does **not** publish a bundle, install
a V4 workflow, change the ruleset or retire anything.

## 2. Read-only facts (2026-10-01)

**Branches and settings** (GET-only reads):

- The history is linear: `main` `ecb03726` ⊂ `codex/guards-principles-plan` `57647c9a` ⊂
  `codex/v4-development-base` `5f6008ee`.
  - `main` is 569 commits behind `codex/guards-principles-plan`.
  - The development branch is 359 commits ahead of it.
- `codex/guards-principles-plan` is the merge of PR #107. That PR's head `732f8d65` passed all 13 required contexts
  on 2026-09-21; nothing has run on this branch since.
- The default branch is `main`, and there are no open pull requests. The repository allows merge, squash and rebase
  merges.

**Ruleset 23459908** "IFX V3 Required Checks":

- It is active on `~DEFAULT_BRANCH` and on `refs/heads/codex/guards-principles-plan`, with no bypass actors.
- Rules: deletion, non-fast-forward, pull request (0 approvals, thread resolution required), and 13 required
  contexts with `strict`.
- While the default branch is `codex/guards-principles-plan`, `main` is outside the ruleset. This is what makes a
  plain fast-forward push possible (1A).

**V3 on a pull request:**

- Every verdict comes from the base commit's `Invoke-IFXTrustedBase.ps1`.
- `v3-pre-diff` requires exactly one changed `*.plan.json` in the V3 plan format, which differs from the format of
  this Plan: it has `areaIds`, `ruleIds` and `decisionPaths`, and no other fields. `v3-pre-diff` validates the real
  diff against that plan.
- `docs/guards/**` is the risky area `guard-rules`, and `docs/architecture/review/gates/**` is `gate-input`; both
  need decisions.

**The allowlist:**

- `docs/guards/V3_ifx/tests/ci/Test-CutoverPreservation.ps1` requires the top level of `docs/guards` to be exactly
  `plans`, `V3` and `V3_ifx`.
- The file is in trusted component `tcb.validation.package-tests`. Changing it therefore needs a base
  `change-trusted-base` authorization in the two-PR flow (`stages/diff/authorizations/README.md`):
  1. the authorization PR adds only the record and its V3 plan pair;
  2. the change PR deletes the record;
  3. the head candidate must pass base-owned validation and parity;
  4. a record can be used once.
- The record binds the exact base and head blobs, and its plan and decision paths must exist in the change head.
- The precedent is `dbe6c9f5` / `a50142ad` (P11.5 base test fixture).

**Non-lab differences** between `codex/guards-principles-plan` and the development branch (everything else is
lab: `candidates`, `inventories`, `plans`, `v4-adoption`, `TODO.md`, `artifacts`):

| Set | Paths |
| --- | --- |
| IFX-V4-005 | `src/ApiHost/IFX.ApiHost/Runtime/RuntimeDrainCoordinator.cs`, `tests/IFX.IntegrationTests/Runtime/RuntimeDrainCoordinatorTests.cs` |
| G03 | `docs/architecture/review/gates/G03/contract-event-governance.en.md`, `.zh-CN.md`, `docs/architecture/review/evidence/gates/G03/G03-closeout.md`, `docs/guards/V3_ifx/shared/decisions/history/20260924-v4-ifx-c2d-g03-current-documentation.json`, `docs/guards/V3_ifx/shared/policy-config.json` (registers that decision), `tests/IFX.IntegrationTests/Composition/Plan06DependencyBoundaryTests.cs` |

`.gitattributes` (including `docs/guards/** text eol=lf`), `.github` and `CODEOWNERS` are identical on both branches.

**Finding F-C1 — the 0.5.1 bundle cannot run on a `main` that admits only `v4-adoption`.**

The bundle pins three lab paths that must exist in the Target:

- `ifx-c1-evaluated-reference` requires staged graph evidence from
  `docs/guards/candidates/ifx-gate-coverage-c1r2b/Invoke-IFXEvaluatedGraphProducer.ps1`. The consumer compares the
  producer path string and hash. The staging script runs the producer from the Target, and the producer reads its
  sibling `modules/ifx-c1-evaluated-reference/policy.json`.
- The Profile's `evidence-lineage.json` names the staging script
  `docs/guards/candidates/ifx-i2b-051/Invoke-IFX050EvidenceProducers.ps1`.

The specimen also runs the aggregate script from `candidates/ifx-i2b-051`, but that path is not bound in the bundle.

All other bundle mentions of `docs/guards/candidates`, `V3` or `V3_ifx` are provenance fields or V3 authorities
that exist on `main`. The G03 documents the bundle pins differ between `codex/guards-principles-plan` and the
development branch, so the G03 set must reach `main` before the V4 workflow can pass.

This does not block I2-C, whose allowlist entry does not depend on the bundle's content. It does block I2-D (see
RC2).

## 3. Operator rulings needed

| Ruling | Question | Options | Recommendation |
| --- | --- | --- | --- |
| **RC1** | Where the pull requests go | (a) into `codex/guards-principles-plan` first (same ruleset, same 13 contexts), then 1A fast-forwards `main` once at the end; (b) 1A first, then pull requests into `main` | **(a)**. V3 CI is exercised again (it has not run since 2026-09-21, so a runner-image drift would show up) before any setting changes; the default-branch window happens once, with the final state; `main` moves once |
| **RC2** | Close F-C1 | (X1) I2-B amendment A3, bundle 0.5.2: move the graph producer and its policy, the staging script and the aggregate into `v4-adoption`, then rerun the C6 chain as in A2; (X2) admit a curated second entry under `docs/guards/candidates` | **X1**, so the allowlist stays at the one entry 2B decided. A3 is local and has its own Plan; it can run while I2-C waits on CI, and it must finish before I2-D |
| **RC3** | How strict the new allowlist is | (a) the exact set `plans`, `V3`, `V3_ifx`, `v4-adoption`, with the change PR creating `v4-adoption/README.md`; (b) `v4-adoption` optional | **(a)**. It keeps the test exact, and a negative control proves that any other entry still fails |
| **RC4** | Decision for the admission | (a) a new V3 decision record, registered in `policy-config.json`; (b) reuse D15, D20 and D23 only | **(a)**. Admitting a new `docs/guards` entry is a new governance decision. C3 shows whether registering it also needs a `weaken-policy` record |
| **RC5** | Merge method | merge commit, squash or rebase | **Merge commit**, as for PR #107: the merged commits are exactly the rehearsed and authorized heads |
| **RC6** | `docs/guards/TODO.md` | (a) stays on the development branch during I2; the `main` edition of the README points to it; (b) move it to `v4-adoption/TODO.md` now | **(a)**. It keeps I2-C minimal; I2-D can move it with the curated package |

Rulings (2026-10-01): **RC1 (a)** pull requests into `codex/guards-principles-plan` first, 1A last; **RC2 X1** bundle
0.5.2 through I2-B amendment A3 (own Plan) before I2-D; **RC3 (a)** exact four-entry allowlist with
`v4-adoption/README.md`; **RC4 (a)** new V3 decision; **RC5** merge commit; **RC6 (a)** `TODO.md` stays on the
development branch.

## 4. Steps

Local steps are C0–C4. From C5 on, **each numbered step is a separate authorization**, and a push and a merge are
two separate authorizations. Evidence: `D:/IFX-Root/v4-todo-008-evidence/I2C-main-promotion` (`evrun.py --ev
I2C-main-promotion`); records under `artifacts/guards/p10-ifx-i2c/`.

| Step | Action | Kind |
| --- | --- | --- |
| C0 | Commit this Plan pair after `plan validate`. Correct the stale status texts: the I2-B Plan status line, §10 status and §10.7 still say "A2-12 needs authorization"; the program Plan still says "I2-A next"; the TODO entry for IFX-V4-001 | Local |
| C1 | Remote snapshot, GET only: default branch, the three branch heads, ruleset 23459908 (full JSON and its SHA-256), repository merge settings, open pull requests, and the check rollup of PR #107. Record `c1-remote-snapshot.json` | Local, GET |
| C2 | Prepare the pull request heads with `docs/guards/candidates/ifx-i2c/New-IFXI2CPullRequestHeads.ps1`, in a disposable clone at `57647c9a`, byte-copying from the development branch:<br>• **P1**: the IFX-V4-005 set;<br>• **P2**: the G03 set;<br>• **P3**: the allowlist change to `Test-CutoverPreservation.ps1` (RC3), the new V3 decision and its registration (RC4), and the `main` edition of `docs/guards/v4-adoption/README.md`.<br>Each head gets its own V3-format plan pair under `docs/guards/plans/`. Where C3 shows an obligation, an authorization plan pair is added. The script checks that every non-plan blob equals the development branch blob (P3's new files excepted) | Local |
| C3 | Rehearsal `candidates/ifx-i2c/Invoke-IFXI2CRehearsal.ps1`. It runs in a clone outside the repository and uses the base commit's own trusted runner, verifier and generator (pattern: `Invoke-IFXProtectedChangeRehearsal.ps1`). For each head in order (P1, P2, P3, each on top of the previous):<br>1. `v3-pre-diff` with the head's plan; the derived obligations are recorded;<br>2. the package tests (`ifx-package-test`, which include `Test-CutoverPreservation`) and historical integrity;<br>3. G03 specialized for P2;<br>4. solution quality for P1.<br>For every obligation, it runs the two-PR sequence: generate the record with `New-IFXTrustedBaseAuthorization.ps1`; the change without the record fails; the authorization PR alone passes; the change consuming it passes; reusing it fails.<br>Negative controls for P3: an extra top-level entry fails; the unchanged base test fails on `v4-adoption`; removing `v4-adoption` fails (RC3a). Record `c3-rehearsal/` | Local |
| C4 | Operator review of the prepared diffs, plans, records and rehearsal. Decision `c4-decision.json`; commit locally | Local, **operator** |
| C5 | **P1**: push branch `codex/i2c-p1-drain-wait-fix` and open the PR to the RC1 target. After all 13 contexts pass, a separate authorization merges it (RC5). The operator reports the checks, or asks for a single GET read; nothing polls | **Remote** |
| C6 | **P2** as C5. If C3 found an obligation: first P2a (authorization PR, then merge), then P2b (change PR, then merge) | **Remote** |
| C7 | **P3**:<br>1. regenerate the record against the then-current target head; it may differ from the C3 record only in base identities;<br>2. P3a: authorization PR, then merge;<br>3. P3b: change PR, then merge | **Remote** |
| C8 | 1A-1: set the default branch to `codex/guards-principles-plan`; GET verify. **C8–C10 run in one sitting**, not near the V3 monthly schedule (03:17 UTC on the 1st) | **Remote setting** |
| C9 | 1A-2: plain `git push origin <head>:refs/heads/main`, where `<head>` is the RC1 target's head after C7. No force; GET verify | **Remote** |
| C10 | 1A-3: set the default branch back to `main`; GET verify. `commands/Invoke-IFXCiContract.ps1 -Remote` must pass: 13 required checks, `strict`. The ruleset JSON must equal C1 | **Remote setting** |
| C11 | Post-state record `c11-post-state.json`: the top level of `docs/guards` on `main` is exactly `plans`, `V3`, `V3_ifx`, `v4-adoption`; the P1–P3 blobs equal the development branch blobs; the result of the push-triggered V3 run on `main` (one GET read). Merge `origin/main` into the development branch so it stays a superset. Two conflicts are expected and resolved by rule: `docs/guards/v4-adoption/README.md` keeps the development edition (the lab index) with a note naming the `main` edition, and `docs/guards/V3_ifx/shared/policy-config.json` takes the `main` version (it only adds the admission decision). Every other P1–P3 path is identical on both sides. Receipt `v4-adoption/migration/ifx-i2c-main-promotion-receipt.json`; TODO and program Plan updated; commit | Local, GET |
| C12 | Push the development branch (fast-forward) | **Remote** |

If RC1 is (b), C8–C10 move before C5, and P1–P3 target `main`.

## 5. Acceptance

- Every remote step was authorized on its own. There was no force push, no `--admin`, no bypass and no ruleset
  change; the ruleset after C10 equals C1.
- Every pull request's final head passed all 13 contexts. Every protected change was covered by exactly one
  consumed base authorization.
- At the end:
  - the default branch is `main`, and `main` equals the RC1 target's head;
  - the top level of `docs/guards` on `main` is exactly `plans`, `V3`, `V3_ifx` and `v4-adoption`, and a negative
    control proves that any other entry fails;
  - the IFX-V4-005 and G03 sets on `main` are byte-identical to the development branch.
- `main` contains no candidate, inventory, artifact, bundle, V4 workflow or TODO file.
- P10.GATE, cutover and V3 retirement stay false.

## 6. Stop conditions

Each of these stops I2-C. The evidence is kept, and nothing is retried silently.

- The C1 snapshot is not what §2 states, or `codex/guards-principles-plan` or `main` moves unexpectedly.
- A rehearsal result is not the expected one, or an obligation appears that is not in C3. This includes a D18
  governing-policy finding on the G03 documents, which needs its own ruling.
- A required context fails for any reason other than a content defect of the pull request. Examples are runner-image
  drift and a base-engine false failure. A fix needs its own Plan; a break-glass is the operator's decision under
  `V3_ifx/docs/authored/trusted-base.md`.
- Anything would need a force push, `--admin`, a ruleset or bypass change, or a change to the V3 workflow.

## 7. Rollback

- **Before C9**, every step is reversible:
  - close a pull request;
  - revert a merged one through a V3-judged pull request;
  - if anything fails between C8 and C10, set the default branch back to `main` at once, and `main` is unchanged.
- **C9 cannot be reversed.** Once `main` is the default again, the ruleset forbids non-fast-forward updates and
  deletion. Recovery is forward-only, through revert pull requests. The previous head `ecb03726` stays an ancestor
  and is recorded in C1.

## 8. Planned paths

- `docs/guards/plans/20261001-v4-ifx-i2c-main-promotion.md` and `.plan.json`
- `docs/guards/plans/` V3-format plan pairs of P1, P2, P3 and their authorization PRs (`2026MMDD-v4-ifx-i2c-*`)
- `docs/guards/candidates/ifx-i2c`
- `artifacts/guards/p10-ifx-i2c`
- `docs/guards/v4-adoption/README.md` (the `main` edition, reconciled with the development edition) and
  `docs/guards/v4-adoption/migration/ifx-i2c-main-promotion-receipt.json`
- `docs/guards/V3_ifx/tests/ci/Test-CutoverPreservation.ps1`, the new V3 decision under
  `docs/guards/V3_ifx/shared/decisions/history/`, `docs/guards/V3_ifx/shared/policy-config.json` and the transient
  records under `docs/guards/V3_ifx/stages/diff/authorizations/`
- the P1 and P2 paths of §2 (already changed on the development branch; they arrive on `main` byte-identical)
- `docs/guards/TODO.md`, `docs/guards/plans/20260929-v4-ifx-i2-p10-gate-successor.md`,
  `docs/guards/plans/20260929-v4-ifx-i2b-ci-evidence-and-bundle.md`

## 9. Out of scope

- The bundle 0.5.2 relocation (RC2 X1). It is I2-B amendment A3, with its own Plan.
- Publishing the bundle and the curated package (I2-D); the V4 workflow (I2-E); the ruleset (I2-F); the coexistence
  window and P10.GATE (I2-G).
- The Linux blocking decision and the V3 Linux bridge; V3 retirement (I3).
- Promoting the lab history or the historical V4 Plans to `main`. Under 2B the development branch stays the lab and
  evidence branch, referenced by commit.

## 10. Progress

- **C0 (2026-10-01).** Plan pair and status corrections committed (`48c174e3`).
- **C1.** GET-only snapshot passes (`c1-remote-snapshot.json`, evrun 003; runs 001–002 failed on script defects of the
  snapshot itself): every fact of §2 holds; ruleset canonical SHA-256 `857a51aa…`.
- **C2.** `candidates/ifx-i2c/pr-spec.json`, the authored files under `pr/` and `New-IFXI2CPullRequestHeads.ps1`.
  An unrecorded discovery run showed that P2 and P3 each need a `change-trusted-base` record (`policy-config.json` is a
  trusted component; for P3 also the test) and a `weaken-policy` record (the decision history is `trust-meta-policy`),
  so authorization pull requests P2a and P3a were added; P1 needs none.
- **C3.** `Invoke-IFXI2CRehearsal.ps1` passes (evrun 007, `c3-rehearsal/rehearsal.json` `eee37e09…`): 36/36 steps as
  expected with full parity and solution quality; both two-PR sequences (early change fails, authorization PR passes,
  consuming change passes Diff, candidate parity, policy candidates, Validate, candidate tests, Architecture, Historical
  Integrity and G03); allowlist controls (extra, differently cased and missing entries fail; the unchanged base test
  rejects `v4-adoption`); a consumed record cannot be replayed; final `docs/guards` is exactly `plans`, `V3`, `V3_ifx`,
  `v4-adoption`, with every path equal to its source. Trials 1–2 (evrun 004–005) and attempt 1 (evrun 006, all 36 steps
  as expected but a wrong final-state string comparison) are kept under `artifacts/guards/p10-ifx-i2c-trials/`.
  Fixes: generated records are committed with LF; final-state checks.
- **C4.** Review packet `c4-review/review-packet.json` `897c7d68…` and `review.md` (evrun 008). Accepted by the operator ("接受，授权 C5"); decision `c4-decision.json`.
- **C5.** Target still `57647c9a`. P1 rebuilt on it (`1b234ace`, byte checks pass), the trusted Diff re-run on that exact head
  passes; branch `codex/i2c-p1-drain-wait-fix` pushed and verified; PR
  [#109](https://github.com/von12549/IFX/pull/109) opened to `codex/guards-principles-plan` (`c5-p1.json`). 13/13 passed (one
  GET read); merged with a merge commit after authorization: target `218591ec`.
- **C6.** `New-IFXI2CAuthorizationHead.ps1` on `218591ec` (evrun 009): both P2 records regenerated by the target's
  generator are byte-identical to C3; the P2a head `5df34289` passes the trusted Diff, the candidate check (no trusted
  component change) and Validate. Pushed and verified; PR [#110](https://github.com/von12549/IFX/pull/110) opened
  (`c6-p2a-head.json`, `c6-record.json`). 13/13; merged after authorization ("授权合并 #110"): target `4a787504`, records in
  the base. P2 change head `b0f16df4` (deletes both records) passes the preflight on `4a787504` with the target's runner:
  trusted Diff, candidate check with full parity, policy candidates, Validate, G03 (evrun 010, `c6-p2-change-head.json`).
  Pushed and verified; PR [#111](https://github.com/von12549/IFX/pull/111) opened. Next: merge #111 after 13/13
  (authorization).
