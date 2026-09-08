# Plan 02 reliable-events operations runbook

## Triage

1. Confirm the process role. Dispatcher must be absent from `api` and present in `worker`/`all`.
2. Query each producer store through the authorized management job using EventId, time range, event type, or tenant. Return metadata only; never export payload.
3. Inspect pending count, oldest age, retry count, dead-letter count, last success, and lease age. Apply the thresholds in `deployment/g04/backpressure-policy.json`.
4. Correlate by EventId and correlation ID. Do not log financial values or raw tenant identifiers outside the approved pseudonymized channel.

## Failure decisions

| Condition | Action |
|---|---|
| Database unavailable | Stop claim attempts through host failure policy; restore database, verify migrations/history, then resume Worker. |
| Transport/consumer transient failure | Leave the same logical message Pending; bounded retry/backoff handles recovery. |
| Expired lease | A different instance may reclaim it; stale owner completion must fail. |
| Invalid producer, tenant, or payload | Keep the item in Holdings quarantine; do not create Inbox or Application context. |
| Business rejection | Ack the transport path after writing the bounded quarantine reason; investigate the source fact. |
| Maximum attempts | Review the dead-letter metadata and consumer compatibility before replay. |
| Growing or stalled backlog | Apply warning/critical policy, stop backlog-expanding commands when the approved backpressure adapter is connected, and restore consumers before producers. |

## Controlled replay

1. Obtain Operations and module-owner authorization and record EventId, reason, requester, target handler version, and expected idempotency behavior in the change/incident record.
2. Dry-run `QueryAsync` for the exact EventId and confirm `DeadLettered`, correct producer/type/tenant, and a compatible Holdings adapter. Do not retrieve payload into tickets or logs.
3. Call `ReplayDeadLetterAsync` for that EventId. It retains EventId, Envelope, payload, sequence, and attempt history while resetting only state, next-attempt, lease, and bounded error code.
4. Observe delivery. A completed Inbox remains a duplicate/no-op. Forced business reprocessing requires a separately designed and approved `ReprocessingRequest`; never mint a new EventId to evade deduplication.
5. Attach before/after diagnostics and the operator audit record. Batch replay repeats the same checks per item and must be bounded.

## Reconciliation and rollout

For reconciliation, compare producer delivered EventIds with Holdings Inbox EventIds within the agreed window, then classify missing rows as pending, dead-lettered, quarantined, or an actual projection drift. Do not join module schemas in application SQL; export bounded identifiers through an authorized operations job.

Deploy consumer-first: migrate Holdings Inbox/quarantine and start compatible Worker consumers; observe readiness; migrate producer Outboxes; then enable Registry/Transaction producers. Rollback stops new production but keeps consumers and all already-created V1 rows until drained.
