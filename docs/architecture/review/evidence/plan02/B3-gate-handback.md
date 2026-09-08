# Plan 02 / B3 symmetric Gate handback

Date: 2026-09-08  
State: repository-scope complete; production evidence and final signatures remain open.

| Gate | Returned implementation and evidence | B3 disposition |
| --- | --- | --- |
| G01 | Transaction/Registry business changes and producer-local Outbox join the existing `ITransactionParticipant`; Holdings applies command + Inbox through `TransactionProfile.Inbox`. SQL Server tests cover commit, rollback, duplicate, lease expiry, stale owner and replay. | Real E2/E4 callback accepted; no second Behavior/Executor protocol was introduced. |
| G02 | `transaction.OutboxMessages`, `registry.OutboxMessages`, `holdings.InboxMessages` and `holdings.InboxQuarantineMessages` are owned by their module DbContexts and migrations. The 18-ID manifest, fresh/upgrade matrix, schema metadata and zero-pending checks pass. | Real schema-local callback accepted; production Migrator/Worker/API rehearsal remains external. |
| G03 | Two provider-owned V1 events are Active, 20 legacy surfaces are Retired, golden/source reconciliation passes, and Messaging Contracts is physically separated from Runtime. | Plan 02 technical blockers cleared; final owner approvals remain open. |
| G04 | Dispatcher starts only for `worker`/`all`, claims with bounded SQL leases, sends outside transactions, drains through Composition, and exposes the existing backpressure seam. | Repository runtime callback accepted; production health/alert calibration and rollout rehearsal remain open. |
| G05 | Envelope identity is frozen in Outbox; payload omits TenantId and C4 data; the Holdings adapter validates producer/schema/tenant before Application and creates an isolated EventId-based operation. Retry/replay preserve logical identity and invalid input is quarantined with bounded diagnostics. | Real carrier callback accepted; production broker, audit authorization and sensitive sentinel rehearsal remain open. |

Primary evidence:

- [`B3-status.json`](B3-status.json)
- [`Plan02ReliableMessagingSqlServerTests.cs`](../../../../../tests/IFX.DatabaseBoundary.Tests/Plan02ReliableMessagingSqlServerTests.cs)
- [`OutboxDispatcherTests.cs`](../../../../../tests/IFX.IntegrationTests/Runtime/OutboxDispatcherTests.cs)
- [`G03-source-reconciliation.json`](G03-source-reconciliation.json)
- [`B3 LayerGuard comparison`](../layerguard/B3-vs-B2-report.json)
- [operations runbook](../../runbooks/plan02-reliable-events.md)

This handback does not self-approve a Gate. The named Architecture, Application/Module,
Infrastructure/Database, Platform, Security and Operations owners must sign the final immutable
closeout after production-dependent evidence is attached.
