# V4 Guards adoption in IFX

This directory holds IFX's own records for adopting V4 Guards. IFX is a **consumer** of the V4 Guards
product. The product source, releases and trusted-base CI live in the standalone repository
[`von12549/Guard`](https://github.com/von12549/Guard) (canonical since V4-TODO-008 T7, 2026-09-28).

IFX consumes V4 Guards **1.1.6** with `ifx_profile` **0.4.4** since I1 (2026-09-29, Plan
`20260928-v4-ifx-i1-rebind-1-1-6`). Its successor, `ifx_profile` **0.5.0** (evidence produced in CI, I2-B
amendment A1), is certified, human-reviewed and composed locally; the inactive specimen and proposal bind it.
IFX's adoption items (V4-TODO-004 and IFX-V4-001 to IFX-V4-006) are in
[`../TODO.md`](../TODO.md).

`docs/guards/v4` was the former incubation copy of the product. V4-TODO-008 T8 removed it on 2026-09-28
(cleanup receipt below); `git revert` of the recorded cleanup commit restores it.

| Path | Content |
| --- | --- |
| `plans/06-ifx-profile-validation-program.md` | P10 program: `ifx_profile` practice, parity and cutover readiness |
| `plans/07-p10-0-baseline-acceptance.md` | P10.0 released 1.1.0 baseline and Web UI operator evidence |
| `plans/08-p10-1-extension-composition-compatibility.md` | P10.1 extension composition design and gates |
| `plans/09-p10-3-cutover-and-rollback-proposal.md` | Accepted P10.3 design for the 1.1.4 + 0.4.2 tuple (historical) |
| `plans/10-p10-3-successor-standalone-1-1-5.md` | T7 successor: V4 Guards 1.1.5 from `von12549/Guard` + `ifx_profile` 0.4.3 (historical) |
| `plans/11-p10-3-successor-1-1-6.md` | I1 successor: V4 Guards 1.1.6 + `ifx_profile` 0.4.4; Linux C6c passes (IFX-V4-002/003/004) (historical) |
| `plans/12-ci-evidence-design.md` | I2-B design note: evidence produced in CI, the pin split and the two-step 0.5.0 rework |
| `plans/13-p10-3-successor-0-5-0.md` | I2-B A1-8 successor: V4 Guards 1.1.6 + `ifx_profile` 0.5.0; producer, staging and upload steps; four producers re-attest V3 until 0.5.0-b |
| `integrations/github/ifx-cutover-proposal.json` | Inactive cutover proposal, bound to the A1-8 successor identities (0.5.0) |
| `integrations/github/proposed-v4-ifx-guardrails.yml` | Inactive workflow specimen; fetches V4 only from `von12549/Guard`, pins the archive SHA-256, and produces, stages and uploads the IFX evidence |
| `migration/v4-todo-008-ifx-rebinding-receipt.json` | T7 handoff decision and receipt |
| `migration/v4-todo-008-ifx-cleanup-receipt.json` | T8 cleanup receipt: deleted and retained inventories, rollback commit |
| `migration/ifx-i1-rebinding-1-1-6-receipt.json` | I1 receipt: 1.1.6 + 0.4.4 identities, S1–S9 decisions, closed and opened backlog items, T8 coupling correction |
| `migration/ifx-i2b-a1-0-5-0-a-receipt.json` | I2-B A1 receipt: 0.5.0-a candidate identities, A1-3 to A1-9 records, backlog, booleans (not published or active) |

The files 06–09 were moved here with `git mv` from `docs/guards/v4/plans/` and
`docs/guards/v4/integrations/github/`; their history is intact (`git log --follow`). The accepted P10.1–P10.3
decision records under `artifacts/guards/p10-ifx-114/` are historical facts and are not edited.

Nothing here is active. Installing the specimen, publishing the IFX bundle, changing a required context
or ruleset, P10.GATE, cutover and V3 retirement each need their own exact Plan and authorization.
