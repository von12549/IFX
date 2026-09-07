# G04 Phase 5 — Drain conformance

Status: **PRE-READY**. The attainable Host/runtime boundary is implemented; E3 Dispatcher and E4 Inbox integration remain downstream closure conditions.

## Implemented boundary

- `RuntimeDrainCoordinator` atomically changes the process to `Stopping`, cancels the shared `IRuntimeDrainSignal`, rejects new HTTP work with `503`, and waits only for operations already admitted.
- Health endpoints remain reachable during drain so the load balancer can observe NotReady instead of seeing a connection-only failure.
- `RuntimeLifecycle` cannot race from `Stopping` back to `Ready`.
- The checked-in budget is `10s operation < 20s handler < 30s lease < 40s process grace < 45s orchestrator kill`, with `2s` reserved for bounded telemetry flush.
- Compose API and Worker units use `SIGTERM` and a `45s` stop grace. Hangfire consumes the Host cancellation lifecycle; future E3 dispatcher/consumer loops must inspect the shared drain signal before claim/fetch/schedule.

## Automated evidence

`RuntimeDrainCoordinatorTests` proves atomic rejection, bounded in-flight waiting, timeout without invented completion, strict budget validation, and the stopping/readiness race. The Phase 4 SQL fixture proves expired lease reclamation and conditional completion.

## Explicitly not claimed

- No real E3 Dispatcher exists yet, so send/ack/conditional-complete shutdown injection must be rerun by Plan 02 E3.
- No real E4 Inbox integration exists yet, so duplicate absorption after forced termination is not closed.
- The 45-second production orchestrator setting and telemetry exporter flush require platform-specific rehearsal and Operations approval.
