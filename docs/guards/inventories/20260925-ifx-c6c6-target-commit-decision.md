# V4 P10.1 C6c6 target-commit remediation decision

Decision: `ACCEPTED FOR C6c RE-CERTIFICATION`

Remediation commit evaluated: `ba4e590682f21ea8231d7d546beccd8bee780da5`

This decision accepts the C6c6 detector repair. It does not by itself certify
C6c: the unchanged C6c5 parallel certification must still pass with seven fresh
locks bound to the final committed HEAD.

## Implemented binding

Solution, Assembly, Frontend, Database and compiled-Type adapters now resolve
`TargetRoot/.git/HEAD` without launching Git and require each evidence lock's
lowercase 40-hex `targetCommit` to equal that resolved commit. The identical
resolver supports normal repositories, `gitdir:` worktrees, loose refs and
packed refs. Assembly additionally binds its Solution lineage lock; compiled-
Type binds its own lock plus Solution and Assembly lineage to the same commit.

Only adapter SHA-256 fields changed in the five module manifests. Reviewed
capabilities remain unchanged: no network, no write roots, and `pwsh` is the
only declared process. Published 1.1.3 bytes, policy, baselines, waivers and
reviewed ceilings were not changed.

## Focused acceptance evidence

All five owning suites passed with locks generated at the remediation commit.
Each suite includes a disposable lock whose `targetCommit` is forty zeroes and
whose configuration hash is correctly rebound; every such case returned
`error/integrity-failure`.

- Solution: `artifacts/guards/p10-ifx-c5b/test-runs/8c3ef10dbf834fb68db32a97daaba29f/summary.json`,
  SHA-256 `bff3edb180bd52877baf7154adf4a39b98d213d238496fa4f54c7d73a5e90c22`
- Assembly: `artifacts/guards/p10-ifx-c5c/test-runs/2aaf91f10f5f453fbba3fe6c86696fe8/summary.json`,
  SHA-256 `57f084c1193c08bfcde19aed14226c0b0d6778dad45c33939a6b9054003a4b91`
- Frontend: `artifacts/guards/p10-ifx-c5d/test-runs/18255efee01c464eba803e6534828ee2/summary.json`,
  SHA-256 `b8e1680ab74928ef1641e3369597ea38bc2bf3ac65939948fe964b716eb4fcf5`
- Database: `artifacts/guards/p10-ifx-c4b/test-runs/392f63a07391468485910973bbfdb4cc/summary.json`,
  SHA-256 `a1451a59f38da782d479bf3545ff401925be2b174a7d07da059ba175d9fceab4`
- compiled-Type: `artifacts/guards/p10-ifx-c1-r1b/test-runs/cb62e95930144620b1e469925fa8bb5e/summary.json`,
  SHA-256 `ff2ab8783ef25e06833721a2d6b7f42a3c0a76adfc29dda3471f6047086e9d6f`

The first full Solution production attempt observed one failure in
`RuntimeDrainCoordinatorTests.BeginDrain_AtomicallyRejectsNewWork_AndWaitsForExistingWork`.
The isolated test immediately passed, and the complete producer was rerun from
scratch: all 1,277 tests passed and a new controlled Solution lock was issued.
The failed attempt was not used by any downstream lock or acceptance result.

## Remaining certification boundary

Because committing this decision changes HEAD, the focused locks above are
diagnostic evidence only. C6c re-certification must regenerate C6b0 inventory,
all seven locks, bundle and review at the final commit, then pass the unchanged
C6c5 Windows controls plus native Windows/Linux 191-row parity run. C6d/C6e,
P10.2/P10.3 and V3 retirement remain out of scope; G04 remains `PRE-READY`.
