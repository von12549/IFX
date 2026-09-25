# V4 P10.1 C6c6 — evidence-lock target-commit binding

Status: `EXECUTION PLAN — C6c REMAINS BLOCKED`

C6c5 proved that the frozen Solution evidence adapter accepts a lock whose
`targetCommit` is forty zeroes after the lock hash is rebound. Static inspection
found the same shape-only validation in Assembly, Frontend, Database and
compiled-Type evidence adapters. Evaluated-Graph already resolves and compares
the current TargetRoot commit and is not changed.

## Exact remediation

Add one identical read-only Git HEAD resolver to each of the five affected
PowerShell adapters. It reads only `TargetRoot/.git`, supports ordinary
checkouts and `gitdir:` worktrees, resolves loose or packed refs, requires a
lowercase 40-hex commit and performs no Git process invocation. This preserves
the reviewed process ceiling (`pwsh` only), network denial and all root grants.

Each adapter must reject an evidence lock unless its `targetCommit` equals the
resolved TargetRoot HEAD. Assembly must additionally bind its Solution lineage
lock to that commit. Compiled-Type must bind its own, Solution and Assembly
lineage locks to the same commit.

Update each module manifest only for the new adapter SHA-256. Extend each owning
test with a disposable wrong-commit lock whose hash is correctly rebound and
which must return `error/integrity-failure`. Existing success, missing, altered,
stale, source/evidence drift and immutable-root controls remain unchanged.

## Validation and decision boundary

After implementation, run the five focused suites with fresh applicable locks,
the isolated `ifx-package-test`, Formal Pre and exact committed Formal Diff.
Then regenerate C6b0 inventory, all seven evidence locks, bundle and review and
rerun the unchanged C6c5 parallel certification.

Stop without C6c certification if resolving TargetRoot HEAD requires a new
process/network/root capability, if any wrong-commit case is accepted, or if any
published 1.1.3 byte, policy, baseline, waiver or reviewed ceiling must change.
C6d/C6e, P10.2/P10.3 and V3 retirement remain out of scope; G04 remains
`PRE-READY`.

Only this Plan pair, five adapters, their five module manifests, five owning
tests and the C6c6 decision record are planned source paths. Formal Pre must pass
before executable edits.
