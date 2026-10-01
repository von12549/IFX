# IFX I2 — P10.GATE successor for V4 Guards 1.1.6 + `ifx_profile` 0.4.4 (IFX-V4-001)

Status: `ACTIVE — phase division and decisions 1A/2B accepted by the operator (2026-09-29); I2-A complete (2026-09-29); I2-B complete (2026-10-01, bundle 0.5.1, pushed `5f6008ee`); I2-C complete (2026-10-01, `20261001-v4-ifx-i2c-main-promotion`: main promoted to `7b9b53dc`, `v4-adoption` admitted); next: I2-B amendment A3 (bundle 0.5.2, F-C1), then I2-D`

Formal Plan ID: `20260929-v4-ifx-i2-p10-gate-successor`. This is a **program Plan**: every phase
below needs its own exact Plan and authorization, and the remote phases need explicit per-step approval.

## 1. What P10.GATE requires

`v4-adoption/plans/06-ifx-profile-validation-program.md` §8 says P10.GATE passes only when all of these
hold:

- P10.0–P10.3 evidence is complete, including both installed Web UI hands-on records;
- the latest installation is reproduced from a public 1.1.x release;
- all parity gaps are closed;
- rollback is rehearsed;
- V4 has no V3 runtime dependency.

The same section says P10.GATE stayed false after P10.3 for four reasons:

- the exact bundle was not published as a remote-consumable trusted input;
- the inactive workflow was not installed and negative-tested remotely;
- the coexistence window had not run;
- the V3 Linux bridge remained.

After I1, three of the gate conditions already hold: the installation comes from public release 1.1.6,
parity is 52/52 with zero gaps, and rollback was rehearsed in S9.

## 2. Findings of the read-only investigation (2026-09-29)

**F1 — the specimen's Post step cannot pass in CI with bundle 0.4.4 (structural; not recorded before).**

- The 0.4.4 Profile pins six evidence locks by path and SHA-256, and the database authorities by hash:
  solution, assembly, frontend, graph, generated and type locks (`evidenceLockPath`/`evidenceLockSha256`
  in the module configs, `evidence-lineage.json`).
- The locks are produced locally under the git-ignored `artifacts/guards/…`.
- Each lock is bound to one Target commit (`44536a6a`) and expires: the type lock after 1 h, the others
  after 24 h.
- In CI a pull-request head is a different commit, and the locks are absent, stale and bound to the wrong
  commit.
- The inactive specimen (`proposed-v4-ifx-guardrails.yml`) runs `stage run --stage post
  --with-dependencies` on `windows-latest`, so that step would fail closed.
- Pre does not need the locks. S7, and C6e-R1 before it, ran Pre on the installed composition; Post was
  proven only in the local C6c harness, with fresh locks.
- Consequence: V4 can own the V3 contexts covered by Post modules only if the workflow produces the
  evidence itself. That requires producer jobs in the workflow and a Profile that binds producer
  contracts and the head commit instead of fixed lock hashes, which means a new bundle version.
- A new bundle means a new C6c run, human review, composition and parity. **IFX-V4-006 therefore becomes
  relevant, and its fix should come first.**

**F2 — default-branch promotion is blocked by V3's own required check.**

- `main` is at `ecb03726` (2026-09-07). `codex/v4-development-base` is 858 commits ahead: 4153 files,
  including `.github/workflows/v3-ifx-guardrails.yml` and `CODEOWNERS`.
- Ruleset 23459908 "IFX V3 Required Checks" is active on the default branch and requires 13 V3 contexts.
- The required V3 test `docs/guards/V3_ifx/tests/ci/Test-CutoverPreservation.ps1` allows only `plans`,
  `V3` and `V3_ifx` at the top of `docs/guards`. The development branch also has `TODO.md`, `candidates`,
  `inventories` and `v4-adoption`, which is why V3 CI is structurally red there.
- Promotion therefore needs one of two things first:
  - a V3 trust change through the V3 authorization flow on IFX, admitting the V4 adoption paths; or
  - moving those paths out of `docs/guards`. This touches every candidate script, because the scripts
    use repository-relative paths.
- **The promotion itself is a large remote operation that needs your decision on the merge strategy.**

**F3 — installed Web UI hands-on record.**

- Plan 06 §4 and §8 require an operator to exercise the **installed** Web Companion in a browser on the
  exact 1.1.6 + 0.4.4 installation: clean and blocking cases, evidence desk against Host queries, and
  root invariance.
- This is local and needs no bundle change. The operator performs it; the assistant can prepare Targets,
  inventories and the Host-query comparison and verify the result.

**F4 — making Linux blocking.**

- The specimen has no Linux V4 job, and the Linux bridge stays `v3-cross-platform-ubuntu-latest`.
- CI evidence for Linux would come from a Linux job on a GitHub-hosted runner, which has no 9p mount.
  The local C6c Linux pass (I1) is supporting evidence.
- Whether to add that job belongs in the F1 workflow redesign.

## 3. Proposed phases (each its own Plan and authorization)

| Phase | Scope | Local or remote | Depends on |
| --- | --- | --- | --- |
| **I2-A** | Installed Web UI hands-on record for 1.1.6 + 0.4.4 (F3) and a static check that V4 has no V3 runtime dependency | Local; operator in the browser | — |
| **I2-B** | CI evidence design and bundle 0.5.0 (F1): in-workflow producer jobs, Profile bound to the head commit and producer contracts. Fix IFX-V4-006 first. Then C6c, human review, composition and parity; successor specimen with an optional Linux job (F4) | Local; bundle change | — |
| **I2-C** | Promotion prerequisite (F2): V3 trust change admitting the V4 adoption paths, or relocating them; then promote the development branch to `main` | **Remote**: IFX PRs on `main`, V3 two-PR flow | Operator merge-strategy decision |
| **I2-D** | Publish the exact bundle and production review into the trusted base (`docs/guards/v4-adoption/extensions/ifx/<version>`) on `main` | **Remote**: IFX PR | I2-B, I2-C |
| **I2-E** | Install the specimen as `.github/workflows/v4-ifx-guardrails.yml`; remote negative tests (unpublished bundle, hash drift, candidate self-judgment, etc.) | **Remote**: IFX PRs, workflow | I2-D |
| **I2-F** | Add `v4-ifx-required` to ruleset 23459908 | **Remote**: ruleset change, explicit approval | I2-E |
| **I2-G** | Coexistence window with all 13 V3 contexts still required, then the P10.GATE decision record | **Remote**: observation; local record | I2-F |

V3 retirement and removal of the Linux bridge are **not** part of I2. They are I3 (V4-TODO-004) or later
decisions.

## 4. Recommended order

1. **I2-A now.** It is local, needs no redesign, and closes the last missing piece of P10.0–P10.3 evidence
   for the current tuple.
2. **I2-B design next.** It is the real blocker for CI. It starts with IFX-V4-006 (native-result archive
   copy-back), then a design note and a decision point before any bundle change.
3. **I2-C decision in parallel.** How to get V3's required check to accept the adoption paths, and how to
   promote 858 commits (one reviewed merge, or staged). Nothing remote happens without your approval.
4. I2-D to I2-G in order, each with explicit per-step approval.

## 5. Out of scope

- Changes to the Guard product. Any product defect found goes to Guard as a separate Plan.
- V3/V3_ifx retirement (I3).
- IFX-V4-005 (flaky drain test). It is an IFX product fix; it only affects local solution-evidence runs and
  can be scheduled independently.

## 6. Operator decisions (2026-09-29)

The operator accepted the phase division and chose **1A** and **2B**.

- **1A — V3 on `main` without bypass.** `main` (`ecb03726`) has no `docs/guards` and no workflow. Every V3
  verdict runs from the PR base's `Invoke-IFXTrustedBase.ps1`, so a normal PR to `main` can never satisfy
  the 13 required contexts, and ruleset 23459908 has no bypass. The sequence has three remote setting
  changes, each needing the operator's explicit approval:
  1. set the default branch to `codex/guards-principles-plan`, which is already protected by the ruleset
     and green;
  2. fast-forward `main` to it with a plain push while `main` is not the default branch;
  3. set the default branch back to `main`.

  No check is skipped: the 569 commits were merged into `codex/guards-principles-plan` through PRs with all
  13 contexts.
- **2B — a curated adoption package.** I2-B designs a self-contained `docs/guards/v4-adoption/`: the published
  bundle and review, the CI evidence producers, the aggregate or rehearsal script, the proposal and the
  receipts.
  - The V3 trust change (through the V3 authorization flow on the protected branch) admits only the one new
    `docs/guards` entry `v4-adoption` in `Test-CutoverPreservation`.
  - `codex/v4-development-base` stays the immutable lab and evidence branch (858 commits of candidates,
    inventories, artifacts and Plans), referenced by commit hash.
  - The six G03 governance changes that exist only on the development branch go through their own V3
    authorization PRs: two `V3_ifx` files, three `docs/architecture` files and one test.

Order: I2-A; I2-B (starting with IFX-V4-006); 1A whenever approved; then the V3 allowlist change, I2-D to
I2-G.
