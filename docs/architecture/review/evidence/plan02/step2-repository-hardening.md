# Plan 02 repository hardening evidence

Date: 2026-09-08

This evidence closes the repository-owned portion of the post-B3 hardening step. It does not claim
production exporter/alert calibration, a broker rollout, retention-job execution, or human Gate approval.

## Rule-to-evidence map

| Concern | Implementation | Automated evidence |
| --- | --- | --- |
| Delivery metrics | `MessagingTelemetry` BCL meter with low-cardinality module/category dimensions | `MessagingHealthTests`, `OutboxDispatcherTests` |
| Module health | `RuntimeMessagingHealthProbe`, `MessagingOutboxHealthCheck`, G04 thresholds in configuration | `MessagingHealthTests`; full ApiHost build |
| Crash windows | same immutable logical message across retry; completion marker stops reclaim | `OutboxDispatcherTests` three-window matrix; SQL lease/reclaim test |
| Concurrent deduplication | losing Holdings transaction is acknowledged only after observing the durable Inbox winner | `Concurrent_duplicate_delivery_commits_one_business_effect_and_one_inbox_marker` on SQL Server |
| Partition order and claim | SQL `UPDLOCK/READPAST/ROWLOCK`, earlier-Pending exclusion | SQL concurrent-claim and same-partition ordering tests |
| Context chain | inbound EventId becomes OperationId; downstream causation uses inbound EventId; scope restores on success/failure | `HoldingsInboundContextTests` |
| Diagnostics | platform-scoped, permission-protected metadata-only Outbox/Inbox query endpoint | `MessagingOperationsTests` |
| Replay | separate preview/execute permissions, mandatory audit, bounded batch, handler-version fail-closed check, original EventId | `MessagingOperationsTests`; SQL replay identity test |
| Data lifecycle | C0-C2 payload boundary, no payload diagnostics, bootstrap/rebuild/degrade/deletion policy | bilingual Plan 02 design, G05 protocol tests |
| Static architecture | Runtime remains behind Composition; Host consumes Composition only | LayerGuard B3-baseline scan: 189 tests, 32 matched, 0 new, 0 stale |

## Verification result

- `dotnet test IFX.sln --no-restore`: all projects passed, including 105 SQL Server database-boundary tests and 142 integration tests.
- `Invoke-LayerGuard.ps1 -BaselinePath mcp/LayerGuard/baselines/b3.json`: 189/189 tool tests; 32 matched, 0 new, 0 stale.
- `git diff --check`: passed.

Production-dependent items remain explicitly open in the Plan 02 checklist.
