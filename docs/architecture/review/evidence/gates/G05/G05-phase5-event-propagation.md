# G05 Phase 5 — Event Envelope and propagation conformance

Date: 2026-09-08

## Outcome

Phase 5 freezes Event Envelope V1 schema and propagation semantics while retaining an explicit
pre-Active, non-durable boundary. A deterministic golden fixture validates canonical event identity,
UTC time, required/optional fields and forward-compatible unknown fields. A fake
Outbox/dispatcher/carrier/inbound-Adapter/Inbox pipeline exercises the same envelope end to end.

Producer identity comes from trusted runtime configuration, never the payload. Creation captures the
logical EventId, time, tenant scope, correlation, causation and trace once. The fake Outbox stores
immutable envelope/payload separately from mutable delivery metadata. Retry and replay change only
attempt/lease metadata and preserve logical message identity.

The inbound Adapter validates producer allowlist before version, event identity, tenant scope,
correlation/causation and content type. A malformed business tenant is quarantined before Inbox or
Application; a malformed technical trace restarts tracing without rejecting the event. Consumer
execution uses EventId as OperationId and downstream causation while retaining CorrelationId.

## Verification

- Protocol/conformance project: 50/50 tests passed, including 12 Phase 5 cases.
- Golden fixture, unknown-field compatibility, producer injection and all 14 transport headers are
  covered.
- Retry/replay immutability, `(ConsumerId, EventId)` duplicate behavior, malformed trace recovery and
  malformed tenant/producer quarantine are covered.
- Full solution: 1007/1007 tests passed.
- Full build: 0 errors and the unchanged 20 package, nullability and obsolete-endpoint warnings.
- LayerGuard: 179/179 tests passed and the 03-A0 baseline check reported no new/stale violation.
- G05 Phase 5 guard: passed with all cumulative Phase 0–5 checks true.

## Remaining downstream evidence

Plan 02 must execute the linked suite against real module event sources, database Outbox/Inbox,
Dispatcher and transport. No durable queue, broker, dead-letter or replay engine was added in this
phase, and no G03 event identity is promoted from Proposed by this evidence.
