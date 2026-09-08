# G05 Phase 8 — failure, replay and compatibility conformance

Date: 2026-09-08

## Outcome

The machine-readable Phase 8 policy fixes the D19/D21 disposition matrix across Diagnostic, Client,
Business, Transient, Permanent and Security failures. Each class has an explicit retry decision and
terminal action, so invalid context cannot enter an unbounded retry loop or silently continue across a
tenant boundary.

Event type, schema version, EventId, trusted producer, tenant, correlation and causation are validated
in that exact order before an Inbox write or Application execution. Every rejection has a stable reason
code. Malformed trace context is treated separately as a safe Diagnostic outcome: the technical trace
is restarted while the otherwise valid event continues.

## Quarantine, retry and replay

The conformance carrier freezes envelope and payload bytes independently from mutable delivery state.
Permanent and Security failures create quarantine records whose diagnostics contain only bounded reason,
class, source, timestamps, count and alert key. Raw payloads, headers, event/tenant/correlation IDs and
exception details are prohibited. Security failures additionally emit a bounded audit and alert.

Transient failure changes only attempt, lease, next-attempt time and stable last-error code. Dead-letter
replay retains the original EventId, so a completed Inbox still deduplicates by consumer and EventId.
Forced work is not disguised as replay: it requires a separate ReprocessingRequest, new RequestId,
OriginalEventId, bounded reason, pseudonymous requester reference and independent approval reference.

## Compatibility and metrics

The registered legacy adapter has an owner, exact source identity, metric reason and mandatory expiry.
It may synthesize correlation and causation only, sets envelope provenance to `synthesized`, and fails
closed at expiry. EventId, producer, tenant, scope, event type and schema version are never synthesizable.

Bounded metric families cover context, envelope, tenant and producer rejection, redaction and compatibility
synthesis. Only policy identifiers may be labels; raw user, tenant, event, correlation, causation, request,
email, account and resource values are rejected.

## Verification

- Protocol and conformance suite: 74/74 passed, including 24 Phase 8 cases.
- Full solution: 1041/1041 tests passed, including 99 SQL Server database-boundary cases.
- Full build: zero errors and 14 existing package warning instances; existing nullability and
  obsolete-endpoint warnings remain visible in project compilation output.
- LayerGuard: 179/179 passed; the 03-A0 baseline has no new or stale violation.
- Cumulative G05 Phase 8 guard: passed with all Phase 0–8 checks true.

## Truthful remaining evidence

The quarantine store, Inbox, retry worker, audit/alert capture, dead-letter replayer and compatibility
registry exercised here are test carriers. They are intentionally labelled
`pre-active-fake-carrier-conformance` and do not establish durable production capability. Plan 02 must
run these semantics against the real database Outbox/Inbox, Dispatcher, broker, quarantine/dead-letter
storage and replay controls before G05 can close. Production audit/alert and metric evidence also remains
pending Phase 11.
