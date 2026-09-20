# P11.4 final aggregate publication

This formal aggregate plan publishes the accumulated Plan 06 checkpoints as one real pull request against `codex/guards-principles-plan`.

It is intentionally exhaustive: `plannedPaths` records every changed path in the accumulated candidate. The pull request must consume exact base authorizations for protected removals, trusted-component changes, and policy weakenings; no authorization is embedded in this plan.

Acceptance requires the complete local validation set, all 13 required PR checks, and the additional `workflow_dispatch` run with `windowsCoverage=full` required by D35.

