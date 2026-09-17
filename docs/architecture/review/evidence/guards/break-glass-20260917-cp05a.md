# Break-glass record — CP05a authorization consumption fix (2026-09-17)

Plan 06 §11.7 break-glass, executed once under decision D20 (`docs/guards/V3_ifx/decisions/history/20260917-v3-stage-d20-authorization-consumption-and-break-glass.json`) and the runbook in `docs/guards/plans/20260917-v3-stage-cp05a-authorization.md` §4. The machine-readable evidence is in `break-glass-20260917-cp05a/`.

## Authorization and reason

| Field | Value |
| --- | --- |
| Authorizer | `von12549`, repository administrator. Authorized local preparation, then pushes and PRs, then the ruleset writes, each separately |
| Reviewer | `von12549`; no separate reviewer was named, so the authorizer also reviewed |
| Reason | After CP04d, candidate verification requires a change PR to delete the base authorization it consumes, while the base Diff blocked every deletion under `docs/guards/V3_ifx/`. Every trusted component change, including the fix, therefore failed `v3-pre-diff`: a base-engine false failure |
| Failing check | `v3-pre-diff` on PR #41, [run 35178493487](https://github.com/von12549/IFX/actions/runs/35178493487), only message `Protected guard deletions: docs/guards/V3_ifx/stages/diff/authorizations/cp05a-authorization-consumption.json`; the other 12 required checks passed, including candidate verification (`authorized change of tcb.activation.ci, tcb.engine.trusted-base, tcb.generated.stage-gate, tcb.generator.stage-gate, tcb.validation.package-tests`) |
| Affected check | `v3-pre-diff`, removed from ruleset 23459908 for the merge of PR #41 only |

## Sequence

| Step | PR / action | SHA | Time (UTC) |
| --- | --- | --- | --- |
| Authorization PR | #40, merged | head `065b4513e56970a6cc10b6ce57fd801b3e6db1f3`, merge `86b6150d6b6a41266e7f9cbed9f8605f40062cad` | before the break-glass |
| Fix PR updated with base | #41 | head `6a4452d5c24618111c37baee611b452d364c5f25`; the 7 authorized paths had the same object IDs as the reviewed `334c23f` | before the break-glass |
| Before snapshot and remote CI contract | read-only | — | 03:44:50 |
| Temporary ruleset change | `PUT` `ruleset-during-request.json` | — | 03:47:06 (start) |
| Merge of #41 | merge commit, pinned with `--match-head-commit` | merge `852d22bed95bf31296adf472e25bad372f78899f` | 03:47:19 |
| Ruleset restored | `PUT` `ruleset-before-request.json` | — | 03:47:30 (restored) |

The required check was relaxed for 24 seconds. No other PR was open during the window.

## Ruleset proof

| File | sha256 | Content |
| --- | --- | --- |
| `ruleset-before.json` | `5c1cc5eff1c47cd40f528d6ad4092a4a4e005175c82afbe90df0b1e3b6cc7e00` | `enforcement: active`; no bypass actors; `strict: true`; 13 required contexts; `updated_at` 2026-09-16T00:59:25.848+10:00 |
| `ruleset-during-request.json` | `c98d74db03f0f77b8855470f6bf854968887fd80bb15333ab702a75c84faeb96` | Writable fields of the before snapshot, minus only `{"context": "v3-pre-diff", "integration_id": 15368}` |
| `ruleset-during.json` | `3f4ad4759af19ca2b16639b89eed52af7879f8d504ff378baa3be5ee21e00d35` | Checked equal to before except for the removed context and `updated_at`: 12 contexts, `strict: true`, `enforcement: active` |
| `ruleset-before-request.json` | `215d1436fbd52d65011a2e5b34307ea2f6bd3dd6c7b7e7eb41cf071dfb9473c2` | Writable fields of the before snapshot |
| `ruleset-after.json` | `913ff670c1e2c0edba67166f63920c4cb863d46f73bd9b99b33125c7fb4e33f5` | Equal to before except for `updated_at` (2026-09-17T13:47:29.776+10:00) |
| `ci-contract-before.json`, `ci-contract-after.json` | both `b0618d63930ec18ec376075c44191dfb03003b3e7120b385e4e3e2f13a50e614` | `Invoke-IFXCiContract.ps1 -Remote` passed with 13 required checks and `strict`; the before and after reports are byte-identical |

## Local simulation before the break-glass

`cp05a-simulation.json` records the full local two-PR simulation from base worktrees. All 16 checks came out as expected:

- **Authorization PR:** Diff, Validate and HistoricalIntegrity passed; candidate verification reported no trusted component changes.
- **Fix PR:** Diff failed only on the consumed record; Validate, Architecture and HistoricalIntegrity passed; full candidate verification passed.
- **After the simulated break-glass merge:**
  - positive: a normal two-PR change passed Diff with `consumed-authorization` pass, and candidate verification passed;
  - negative: deleting an unconsumed authorization failed.

## Post-restore verification (normal PRs, restored ruleset)

| PR | Case | Result |
| --- | --- | --- |
| #42 ([run 35179928554](https://github.com/von12549/IFX/actions/runs/35179928554)), merge `2c4ed9ae4668cb2e237a2f8a93252b63c95de576` | Authorization for a comment-only change of `trusted-base/Invoke-IFXTrustedBase.ps1` | All 13 checks passed |
| #43 ([run 35180910950](https://github.com/von12549/IFX/actions/runs/35180910950)), merge `95882a61325d03b359eac019400ff2fb21766836` | Positive: the change consumes that authorization | All 13 checks passed. The `v3-pre-diff` trusted-base summary shows `consumed-authorization: pass (Verified consumption of docs/guards/V3_ifx/stages/diff/authorizations/cp05a-verify-runner-documentation.json)`, together with `base-provenance`, `trusted-build-isolation`, `guardrails` and `base-clean-after` passing. Candidate verification passed as an `authorized change of tcb.engine.trusted-base` |
| #44 ([run 35180933117](https://github.com/von12549/IFX/actions/runs/35180933117)), closed without merging | Negative: delete the same authorization without the change | Only `v3-pre-diff` failed, with `Protected guard deletions: docs/guards/V3_ifx/stages/diff/authorizations/cp05a-verify-runner-documentation.json`; the other 12 checks passed |

## Result

- **Fix in effect:** D20 is in place. The trusted Diff accepts only the deletion of an authorization that the base verifier confirms the change consumes. Unconsumed deletions stay blocked, and a normal two-PR change to a trusted component merges without any ruleset change.
- **Ruleset:** ruleset 23459908 is back to its before configuration.
- **Exception closed:** this break-glass was used once. Later trusted component changes follow the normal authorization flow.
