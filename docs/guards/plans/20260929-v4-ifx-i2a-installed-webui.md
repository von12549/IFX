# IFX I2-A — installed Web UI hands-on record for V4 Guards 1.1.6 + `ifx_profile` 0.4.4

Status: `ACTIVE — A0–A7 authorized 2026-09-29 ("1 授权 2 你操作即可，关键步骤留下截图证据"); the assistant operates the browser and keeps screenshots; A8 push needs separate authorization`

Formal Plan ID: `20260929-v4-ifx-i2a-installed-webui`. Phase I2-A of the program Plan
`20260929-v4-ifx-i2-p10-gate-successor`.

## 1. Purpose

P10.GATE requires both installed Web UI hands-on records for the exact tuple
(`v4-adoption/plans/06-ifx-profile-validation-program.md` §4 and §8). The P10.0 record (1.1.0 baseline) exists. The
P10.1 record exists only for 1.1.4 + 0.4.2 (C6e-R1). This phase records it for the I1 tuple, and also checks
statically that the composed V4 package has no V3 runtime dependency. All of this is local. Nothing changes
the installation, the bundle or any remote.

## 2. Frozen inputs

| Item | Value |
| --- | --- |
| Composed installation | `D:/IFX-Root/guard-runtime/releases/v4-guards-1.1.6-ifx-0.4.4`, package `bea54366…`, receipt `receipts/v4-guards-1.1.6-ifx-0.4.4.compose.json` `a75e67bc…` |
| Base installation | `releases/v4-guards-1.1.6`, receipt `a5c47ac8…` |
| S7 decision | `artifacts/guards/p10-ifx-116/s7-044/s7-decision.json` `77acf8ad…` |
| Clean Target | `guard-runtime/fixtures/ifx-i1-clean-044`: detached worktree at `44536a6a`, clean |
| Violating Target | `guard-runtime/fixtures/ifx-i1-violating-044`: detached at `44536a6a`, exactly one untracked `I1S7Fault.cs` |

The Targets are reused read-only from S7; their state must equal the S7 post record. New `StateRoot` and
`EvidenceRoot`: `guard-runtime/state/ifx-i2a-044-webui` and `guard-runtime/evidence/ifx-i2a-044-webui`. Both must
be absent.

## 3. Steps

| Step | Action |
| --- | --- |
| A0 | Commit this Plan pair locally after `plan validate` |
| A1 | Preparation script `docs/guards/candidates/ifx-i2a/Invoke-IFXI2APreparation.ps1`. It verifies the frozen inputs, including the public verifier without `AllowSyntheticFixture`, the Target HEADs and status, and absent output roots. It records the pre-session inventories of the base, the composed installation and both Targets, plus the Git facts |
| A2 | Launch only the installed `Invoke-V4ReceiptedWebCompanion.ps1` with `-Profile ifx_profile`, both Targets, the new State and Evidence roots and a loopback port |
| A3 | **Browser session** (the operator, or the assistant in the in-app browser with the operator watching):<br>1. open the loopback UI and record the receipt, Companion and Host identities and the prerequisite result;<br>2. confirm the UI shows `ifx_profile` 0.4.4 and its Stages;<br>3. on the clean Target, run Pre directly;<br>4. switch to the violating Target and run Pre directly;<br>5. open both runs in the evidence desk.<br>Screenshots are kept |
| A4 | Query `runs` and `evidence` through the installed Host on the same roots. The UI and Host must agree on run IDs, verdicts, findings, coverage and authority hashes. The clean run passes with 10 module results and non-vacuous coverage; the violating run blocks with `IMPORT-DIRECTION` from `ifx-source-policy` |
| A5 | Stop the Companion. Take post-session inventories and Git facts. The base, the composed installation and both Targets must be unchanged; writes are allowed only under the new State and Evidence roots |
| A6 | Check the composed package for V3 runtime dependencies. No module manifest, adapter, dependency lock or Profile may invoke or read `docs/guards/V3`, `docs/guards/V3_ifx`, a V3 command or the LayerGuard tool, matched case-insensitively. Mentions in documentation are listed separately |
| A7 | Decision record `artifacts/guards/p10-ifx-116/i2a-webui-044/i2a-decision.json`, screenshots and query JSON under the same directory. Update `docs/guards/TODO.md` (IFX-V4-001 progress). Commit locally |
| A8 | **Remote (separate authorization)**: fast-forward push of `codex/v4-development-base` |

## 4. Acceptance

- The receipt and package pass public verification before the session.
- The clean UI Pre passes: 10 modules, non-vacuous coverage, zero findings.
- The violating UI Pre blocks with `IMPORT-DIRECTION` from `ifx-source-policy` for the deliberate file.
- The installed Host queries match the UI exactly.
- The base, the composed installation and both Targets are byte-identical before and after the session.
- A6 finds no V3 runtime dependency.
- Nothing is published, activated or changed remotely.

## 5. Stop conditions

Any of the following stops I2-A, and the failure evidence is preserved:

- frozen-input drift, an existing output path, or a verifier or launcher refusal;
- a clean-run failure, or a missing or non-blocking deliberate finding;
- zero coverage, or UI/Host disagreement;
- a protected-root mutation;
- a V3 runtime dependency;
- any need to edit the installation or the bundle, or any remote access beyond loopback.

A failure is a V4 or bundle defect handled by its own Plan.

## 6. Planned paths

- `docs/guards/plans/20260929-v4-ifx-i2a-installed-webui.md` and `.plan.json`
- `docs/guards/candidates/ifx-i2a`
- `artifacts/guards/p10-ifx-116/i2a-webui-044`
- `docs/guards/TODO.md`
