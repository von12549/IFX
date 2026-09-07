# G04 Phase 4 lease/claim reference conformance

## Protocol delivered to Plan 02 E3

`IModuleDispatcherRuntime` is a per-module host contract. Each implementation exposes only its own module identifier and delegates claim/renew/complete to its owning module storage; the Platform host has no shared Dispatcher DbContext. `DispatchLease` carries stable EventId, module/partition/sequence, unique owner, expiry and concurrency token. `DispatcherTuningOptions` bounds batch, poll interval/jitter, lease duration, renewal and clock tolerance without declaring production SLO values.

The SQL Server reference suite proves:

- two claimants use short transactions, `UPDLOCK`/`READPAST` and bounded batches to obtain disjoint work;
- send is intentionally outside the claim transaction;
- completion and renewal require EventId + LeaseOwner + rowversion, so a stale owner cannot overwrite a takeover;
- expiry permits another process to reclaim the same EventId, including the send-success/mark-before crash window;
- the earliest unfinished sequence blocks only its explicit module/partition, while unrelated partitions progress;
- no global ordering or exactly-once guarantee is claimed.

The selection orders modules and sequences for the deterministic fixture. Real E3 scheduling must additionally measure module/partition fairness and apply configured batch/poll jitter/database-load budgets.

## Runtime identity and Hangfire

Every process start creates `ifx-{role}-{sanitized-host}-{pid}-{guid}` with a 128-character maximum. The same identity is exposed to protected management output and overrides Hangfire ServerName. Restart produces a new identity. WorkerCount remains per instance and queues remain explicit configuration; total concurrency is replica count × per-instance WorkerCount.

Recurring registration is a separate, default-off runtime capability. Production must select one orchestrator/leader authority before enabling it; Phase 8 supplies the release sequencing contract. `CriticalWorkerBackgroundService` is the base for E3 critical loops: an unhandled loop failure records `G04-WORKER-CRITICAL-LOOP-FAILED`, sets non-zero exit status and stops the process. Ordinary message failures belong to durable retry/dead-letter state and must not escape the loop.

## Downstream evidence boundary

This is reference conformance, not the real Outbox Dispatcher. Plan 02 E3 must implement module stores, event mapping, transport, fairness and metrics and rerun these semantics against its tables. E4 must prove Inbox duplicate absorption. Until both return evidence, G04-DD03 and final Gate closure remain open.
