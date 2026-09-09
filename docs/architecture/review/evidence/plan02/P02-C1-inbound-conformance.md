# P02-C1 inbound transport conformance

Date: 2026-09-09

Result: **PASSED — E4.9 and Plan 02 Phase 4 repository acceptance complete**

## Boundary implemented

The production in-process sender no longer hands a pre-constructed `EventEnvelope` directly to a
module handler. It now encodes the frozen logical message into transport headers and payload, then
passes that raw carrier through `IInboundIntegrationEventReceiver` and `RawIntegrationEventReceiver`.
The same receiver is the transport-neutral seam a future broker-specific consumer calls.

The receiver validates envelope version, EventId, type/schema agreement, UTC occurrence time,
producer syntax, scope/TenantId, correlation/causation, content type and provenance before resolving
or invoking a module handler. Malformed business context returns a stable quarantine disposition;
the carrier payload and raw header values are not logged.

Trace validation is deliberately different from business-context validation. A malformed
`traceparent` or `tracestate` does not quarantine an otherwise valid business event. The receiver:

1. discards both untrusted trace fields;
2. retains EventId, CorrelationId, CausationId, TenantId and the logical payload unchanged;
3. starts a new root `ActivityKind.Consumer` span;
4. emits only the bounded `ifx.trace.restarted=true` tag;
5. dispatches the sanitized Envelope to the real module handler.

A valid W3C remote parent is retained and continued. The Holdings handler remains responsible for
the event-specific producer allow-list and persists an invalid producer/type pairing to its owned
quarantine table before Application dispatch.

## Automated evidence

| Evidence | Result |
| --- | --- |
| `InboundIntegrationEventTransportAdapterTests` | 8/8 passed, including invalid traceparent, invalid tracestate, invalid EventId/schema/producer syntax/TenantId, valid remote parent and in-process raw-boundary routing |
| `IFX.IntegrationTests` | 150 passed, 0 failed |
| `IFX.Platform.ProtocolContracts.Tests` | 77 passed, 0 failed |
| filtered `Plan02ReliableMessagingSqlServerTests` | 6 passed, 0 failed; real Holdings producer quarantine path retained |
| full `IFX.sln` | 1,085 passed, 0 failed, 0 skipped |
| LayerGuard tool tests | 189 passed, 0 failed |
| strict B4 scan | 39 governed projects, 0 findings, 0 waivers |
| `Test-Plan02C1InboundConformance.ps1` | passed; code path, tests, checklist and readiness agree |

The existing dependency/advisory warnings remain visible and were not reclassified as success.

## Closure decision

E4.9 is complete because the current production transport now traverses a raw carrier boundary and
the receiver proves both branches required by G05: invalid business context stops before the module
handler, while invalid trace restarts observability without changing or rejecting the business
message. This is transport-neutral conformance, not a claim that a production broker has been
selected or deployed.

Plan 02 Phase 4 is complete. P02-C2/E5.7 remains the next slice; no Phase 5–8 or production-release
item is closed by this evidence.
