# P11 activation — install the certified CI candidates

This checkpoint synchronizes the CI workflow template with the P11.4-certified active workflow, renders the declared activation candidates, and installs them through the public deployment command. The activated workflow body and CODEOWNERS rules remain behaviorally identical; activation adds deterministic provenance and managed-block ownership so future drift is machine-verifiable.

The change consumes one exact `change-trusted-base` authorization for the prepared commit. Acceptance requires Generate, Check, Preview, Install, Verify, the base-owned trusted Diff, all 13 pull-request checks, and a post-merge Verify against `codex/guards-principles-plan`. Rollback is limited to the two activation targets and will be rehearsed separately before Plan 06 closeout.
