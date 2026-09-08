# G05 -> Plan 02 Event propagation conformance handoff

## Boundary and ownership

- Accountable owner: `xiaolong-feng` / `@von12549`.
- Delivery owner: the Plan 02 implementer for
  [`02-reliable-integration-events.md`](../../../plans/02-reliable-integration-events.md).
- Revisit trigger: the first producer-owned V1 event, database Outbox/Inbox migration, Dispatcher,
  transport implementation or Holdings inbound Adapter, and again before Active promotion.
- The G05 fake pipeline proves context semantics only. It is not a durable Outbox, Inbox,
  dispatcher, broker, dead-letter or replay implementation.

## Required inputs

1. Use the BCL-only `EventEnvelope` V1 and the schema/golden fixture under this Gate.
2. Apply `event-propagation-conformance-v1.json` to each producer, database Outbox, Dispatcher,
   transport mapping, inbound Adapter and Inbox.
3. Port the cases in
   `tests/IFX.Platform.ProtocolContracts.Tests/EventPropagationConformanceTests.cs` to real database
   and transport fixtures. Preserve the entire logical envelope and payload across retry/replay;
   mutate delivery metadata only.
4. Build consumer `ExecutionContext` only after validation. Use EventId as OperationId, keep
   CorrelationId, and use the inbound EventId as causation for downstream work/events.
5. Quarantine invalid tenant/business context before Inbox/Application. Invalid W3C trace restarts
   technical tracing but does not reject an otherwise valid event.
6. Apply `failure-replay-compatibility-v1.json`: preserve EventId and logical bytes, keep delivery state
   separate, audit Security failures, use separately approved ReprocessingRequest for forced work, and
   fail closed on unregistered or expired compatibility adapters.

## Evidence Plan 02 must return

- Provider-owned source-generated golden schemas for both G03 Proposed events.
- Real producer transaction + Outbox atomicity and immutable-record tests.
- Dispatcher/transport header mapping, retry and replay tests.
- Holdings inbound Adapter + database Inbox duplicate/quarantine tests.
- G01/G02/G03/G04 symmetric handbacks, security approvals and B3 LayerGuard comparison.

Until those artifacts return, the G05 evidence remains explicitly pre-Active and non-durable.

## G05 repository package delivered 2026-09-08

- BCL-only Event Envelope V1, schema, golden fixture, fixed pre-Inbox order and stable reason codes.
- Fake Outbox/carrier/Inbox, retry/replay/quarantine, compatibility expiry, safe diagnostics and bounded
  metric conformance, plus Phase 9 unified verification and bilingual flow/state documentation.
- Handoff state: `delivered-repository-inputs / pending-durable-return`.
