# P11.4 final aggregate authorization

This authorization-only checkpoint pre-authorizes the fixed P11.4 aggregate candidate `5e046c57222e764db711e09ad6f748afff1d7afb` against base `7cf0dc635926323c1bd57e2f2f47d88374d27547`.

The 44 immutable records cover exactly the 649 obligations emitted by the base-owned audit: 42 non-overlapping `delete` records cover 514 protected removals, one `weaken-policy` record covers 134 semantic policy changes, and one `change-trusted-base` record covers the single aggregate TCB obligation across 19 components and 753 changed paths. The audit reported no unregistered policy/configuration path, and candidate policy validation passed all 101 validations.

This pull request contains only the formal plan pair and those authorization records. It does not contain or activate the P11.4 implementation. After it merges into `codex/guards-principles-plan`, the final candidate must merge that exact base, delete all 44 records, regenerate its exhaustive aggregate `plannedPaths`, pass the trusted Diff from an external base worktree, pass all 13 required PR checks, and complete the separate `workflow_dispatch` run with `windowsCoverage=full` required by D35.
