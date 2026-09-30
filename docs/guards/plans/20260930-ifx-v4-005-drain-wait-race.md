# IFX-V4-005 — drain wait reports a timeout although the runtime is already idle

Status: `COMPLETE (2026-09-30; F4 authorized and pushed)`

Formal Plan ID: `20260930-ifx-v4-005-drain-wait-race`.

Prerequisite of I2-B amendment A1 (ruling R4): it must be fixed before the A1-6 C6c. It is an IFX product change
(`src` and `tests`), so it has its own Plan and authorization, separate from the V4 Guards work.

## 1. Finding

- **The flaky test.**
  - `tests/IFX.IntegrationTests/Runtime/RuntimeDrainCoordinatorTests.BeginDrain_AtomicallyRejectsNewWork_AndWaitsForExistingWork`
    starts `WaitForIdleAsync(1 s)`, disposes the only in-flight operation, and expects `true`.
  - It failed in 4 of 126 recorded solution-evidence runs, including I1 S5 attempt 3 and I2-B B2 producer-timing
    attempt 1.
  - Each failure stops the solution producer, so no lock is issued.
- **The cause is in the product.**
  - `RuntimeDrainCoordinator.WaitForIdleAsync` awaits `_idle.Task.WaitAsync(timeoutToken)`, and `_idle` is created
    with `RunContinuationsAsynchronously`.
  - When the last operation completes, `TrySetResult` runs at once, but `WaitAsync`'s completion and the
    timeout's cancellation are both thread-pool work.
  - Under thread-pool starvation (parallel test assemblies, a loaded build machine) the timeout callback can run
    first. The method then returns `false` although the runtime became idle long before the timeout.
  - A draining host would log a drain timeout and treat in-flight work as abandoned when it was not.

## 2. Change

| Step | Action | Effect |
| --- | --- | --- |
| F0 | Commit this Plan pair after `plan validate` | Local commit |
| F1 | **Product.** In `WaitForIdleAsync`, when the timeout is observed, return `_idle.Task.IsCompleted` instead of `false`. Idle reached before the timeout is noticed then wins; a real timeout still returns `false` | `src/ApiHost/IFX.ApiHost/Runtime/RuntimeDrainCoordinator.cs` |
| F2 | **Tests.** The positive test waits with a bound that does not measure scheduling (30 s); its behavioral assertions are unchanged. Add a stress regression test: 500 begin, drain, dispose and wait sequences run in parallel with a 5 s bound, and every result must be `true`. `WaitForIdleAsync_TimesOutWithoutGuessingCompletion` stays and still returns `false` while work is in flight | `tests/IFX.IntegrationTests/Runtime/RuntimeDrainCoordinatorTests.cs` |
| F3 | **Verification.** Solution build and all tests pass. The drain tests pass 200 times in a loop under `dotnet test` with parallel assemblies and a CPU-load generator. The V3 solution quality gate passes locally | Evidence |
| F4 | Local commit; push with the I2-B A1 commits after authorization | **Authorization** |

## 3. Effects on the Guards work

- The file is a live authority of `ifx-g04-runtime` (`drainCoordinator`). Its 47 predicates must still hold, so
  `TryBeginOperation` and the atomic drain stay unchanged.
  - Under 0.5.0-a the pin is gone, so nothing else is needed.
  - Under the certified 0.4.4 bundle the pin would drift. That bundle already cannot follow new commits (IFX-V4-007).
- The C6c of 0.5.0 (A1-6) runs on a commit after F4.

## 4. Results

| Step | Result |
| --- | --- |
| F0 | `plan validate` pass; Plan pair committed `a7d885f7` |
| F1 | `WaitForIdleAsync` reads the idle task once and, on timeout, returns `idle.IsCompleted`. The two `ifx-g04-runtime` predicates that read the file (`newWorkRejectedAtomically`, `inFlightDrainBounded`) still match |
| F2 | Positive test bound 30 s; load check `WaitForIdleAsync_ReportsIdle_WhenIdleWinsUnderParallelLoad` added; timeout test unchanged |
| F3 | Release build 0 warnings. `dotnet test IFX.sln`: 21 assemblies, 1,278 tests pass. Drain tests 200/200 with 12 CPU-load processes. V3 `Quality -QualityTarget Solution` pass; V3 `Specialized -SpecializedGate G04` pass |

- **Control.** With the old coordinator and the new tests, 30 runs under the same load also passed. The load check
  does not force the thread-pool ordering of the race, so it is not a regression test for F1. A deterministic test
  would need an injected `TimeProvider` (constructor, DI registration and the `CancelAfter(timeout)` predicate
  change), which is outside this Plan. F1 rests on the code reasoning in §1, and the 30 s bound removes the test-side
  stall.
- Evidence: `v4-todo-008-evidence/IFX-V4-005` (evrun 001–009, `drain-loop-fixed.json`,
  `drain-loop-old-code-control.json`).

## 5. Planned paths

- `docs/guards/plans/20260930-ifx-v4-005-drain-wait-race.md` and `.plan.json`
- `src/ApiHost/IFX.ApiHost/Runtime/RuntimeDrainCoordinator.cs`
- `tests/IFX.IntegrationTests/Runtime/RuntimeDrainCoordinatorTests.cs`
- `docs/guards/TODO.md`
