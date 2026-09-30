# IFX-V4-005 — drain wait reports idle when idle won the race

Formal V3 plan for the first pull request of IFX I2-C (Plan `20261001-v4-ifx-i2c-main-promotion`, step C5 on the
development branch `codex/v4-development-base`).

`RuntimeDrainCoordinator.WaitForIdleAsync` could report a timeout after the runtime was already idle when the thread
pool was starved: the timeout cancellation was observed first although the idle task had completed. The coordinator
now reports `idle.IsCompleted` when the timeout cancellation fires and the caller did not cancel. The positive drain
test waits at most 30 s instead of 1 s, and a new test drives 500 parallel iterations.

The change was reviewed and verified under IFX Plan `20260930-ifx-v4-005-drain-wait-race` (development-branch commit
`739fc279`): 1,278 solution tests, 200/200 drain runs under CPU load and the V3 solution quality gate pass. The two
files here are byte-identical to that commit.

The only risk-triggered paths are this plan pair (`guard-rules`); D10 governs the formal plan records of protected
history.
