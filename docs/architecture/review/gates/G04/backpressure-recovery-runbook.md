# G04 Backpressure Recovery Runbook

1. Confirm the alert is fresh and identify the exact module and event category. Do not apply a global write outage for one partition.
2. Pause only commands marked as expanding that backlog. Keep safe reads and unrelated module/event production available.
3. Inspect oldest age, processing rate, storage utilization, retry/dead-letter growth, expired leases, and the last successful dispatch together.
4. Restore transport/storage first. Scale compatible Worker replicas only after verifying database capacity and unique runtime identities.
5. Quarantine poison messages; never delete Outbox rows or mark an unacknowledged send as delivered. Dead-letter replay requires owner approval and audit correlation.
6. Replay with the original EventId and compatible consumer version. Observe duplicate handling and backlog slope until age and count stay below warning thresholds for one freshness window.
7. Remove backpressure only for the recovered module/event category. Record timestamps, release id, operator, evidence links, and any threshold change.

Production execution requires E3/E6 signals, module ownership, and Operations approval. This runbook does not authorize destructive message deletion or an automatic database rollback.
