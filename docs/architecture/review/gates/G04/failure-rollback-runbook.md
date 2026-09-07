# G04 Failure and Rollback Runbook

Apply the row in `deployment/g04/failure-matrix.json` matching the first failed boundary. Stop progression immediately; do not skip a stage to make the release appear healthy.

## Database and schema

Use the Gate 02 preflight, restore-point, Migrator, validation, and recovery artifacts. Never invoke EF `Down` automatically. If a migration partially ran, classify committed state from a new connection and prefer reviewed roll-forward. New Worker/API instances stay blocked until the release schema is compatible.

## Consumer-first rollout

If Worker V2 is not Ready, do not start API V2 producers. If API rolling deployment fails, keep healthy old API replicas and the expanded schema. Once any V2 event was produced, an API rollback must retain a V2-capable Worker until Outbox, Inbox, dead-letter, and replay evidence proves zero old-version demand.

## Runtime and messaging

A single Worker crash is recovered by durable Hangfire state or lease expiry; duplicate delivery remains possible. Transport/storage failure preserves Outbox truth and uses retry plus scoped backpressure. A fleet failure pauses only related production and follows the backpressure recovery runbook. Never delete pending messages, skip poison records without audit, or mark an unacknowledged send delivered.

## Shutdown

After the configured grace expires, forced exit is allowed. Do not extend shutdown without a bound. Recovery relies on durable lease/job/inbox state and must correlate release, runtime instance, EventId/job id, failure reason, and operator action without recording secrets or payloads.

Every recovery ends with a fresh schema/readiness check, backlog/replay observation, and an immutable evidence reference. Production execution requires the owners listed in the Phase 12 handoff.
