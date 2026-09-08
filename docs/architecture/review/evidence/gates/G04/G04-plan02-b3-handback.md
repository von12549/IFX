# G04 Plan 02 / B3 runtime handback

Date: 2026-09-08

Plan 02 returns a real `IFX.Platform.Messaging.Runtime` dispatcher reached by the ApiHost only
through `IFX.Platform.Messaging.Composition`. `api` does not start consumers or dispatchers;
`worker` and `all` do. Claiming is bounded and lease-based, transport send is outside the claim
transaction, stale completion is rejected, failures enter bounded retry/dead-letter state, and
shutdown participates in the existing runtime drain coordinator.

Automated evidence is in `OutboxDispatcherTests`, `MessageBackpressurePolicyTests`, runtime-profile
and drain tests, and `Plan02ReliableMessagingSqlServerTests`. B3 LayerGuard is baseline-clean at
32 matched / 0 new / 0 stale.

Still open for final G04 closure: production broker wiring, capacity/threshold calibration, health
and alert integration, consumer-first rollout/rollback rehearsal, and Operations approval.
