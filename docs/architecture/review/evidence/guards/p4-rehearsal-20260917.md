# Protected change two-PR rehearsal and ruleset `strict` evidence (2026-09-17)

Plan 06 P4.6 and P4.7 evidence for checkpoint CP06c. Both runs used the merged base `3edb78a` (PR #53, CP06b2) and only read GitHub; nothing was pushed.

## P4.7 — two-PR rehearsal

Command, run from the CP06c working tree against the merged base:

```powershell
pwsh -NoProfile -File docs/guards/V3_ifx/trusted-base/Invoke-IFXProtectedChangeRehearsal.ps1 -BaseRevision 3edb78a -EvidencePath <report>
```

The rehearsal works in a disposable clone outside the repository. The base commit's own trusted runner, candidate verifier, policy candidate validator and authorization generator judge every step. One prepared change combines three protected operations:

- **`move`:** `docs/guards/V3_backup/architecture` moves to `docs/guards/V3_backup/design`, a protected directory;
- **`weaken-policy`:** the title of rule `profiles/ifx/rules/L1.2.json` changes, and the profile views are regenerated;
- **`change-trusted-base`:** a behaviour-equivalent comment is added to `history/Invoke-IFXHistoricalIntegrity.ps1`.

| Step | Base | Head | Result |
| --- | --- | --- | --- |
| Authorization PR, trusted Diff | `3edb78a` | `40b1e7e` | pass: no protected changes |
| Authorization PR, candidate verification | `3edb78a` | `40b1e7e` | pass: no trusted component changes |
| Change opened before the authorizations exist | `3edb78a` | `e4e91f7` | fail as expected: uncovered protected removals |
| Change PR, trusted Diff | `934134d` | `45201ab` | pass: all three records consumed |
| Change PR, candidate verification (full fixed corpus parity) | `934134d` | `45201ab` | pass: authorized change of `tcb.engine.historical-integrity` |
| Change PR, head policy candidates | `934134d` | `45201ab` | pass |
| Change PR, Validate with explicit head | `934134d` | `45201ab` | pass |
| Replay against the merged change | `617d0ee` | `8830470` | fail as expected: the consumed record is no longer in base |

`934134d` is the base after the authorization PR merged, and `617d0ee` is the base after the change PR merged. The complete report, with the three generated records, is `p4-rehearsal-20260917/protected-change-rehearsal.json`.

The first rehearsal run changed the rule without regenerating the profile views. The CP06b2 base accepted that change in the trusted Diff, and its head policy candidate validation has no views check. Only the candidate parity step caught it, as a Validate `profile-views` failure. That step runs only because the change also touched a trusted component, so a policy-only pull request with stale views would have merged and broken Validate for the next base. CP06c therefore adds a base profile views check to `Test-IFXPolicyCandidates.ps1`, and makes the rehearsal and fixtures regenerate views.

## P4.6 — ruleset `strict`

`docs/guards/V3_ifx/ci/Invoke-IFXCiContract.ps1 -Remote` issues only GET requests through the GitHub CLI. It confirmed that ruleset 23459908 matches `ci/jobs.json`:

- `ruleset-identity`, `ruleset-active`, `ruleset-strict` and `ruleset-contexts` all pass;
- 13 required checks match.

The report is `p4-rehearsal-20260917/ci-contract-remote.json`.
