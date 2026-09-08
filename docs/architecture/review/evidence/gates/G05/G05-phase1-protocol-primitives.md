# G05 Phase 1 protocol primitives

Date: 2026-09-08

## Result

`IFX.Platform.Context.Contracts` and `IFX.Platform.Messaging.Contracts` are now separate .NET 8 protocol assemblies with no package or project references. They contain no ASP.NET, authentication implementation, Activity, DI, serializer, persistence or broker dependency.

The context assembly owns non-empty canonical `CorrelationId`, `OperationId`, `CausationId` and `RequestId` helpers; explicit Tenant/Platform scope types; minimal actor/source references; provenance; and a versioned BCL-only `ContractRequestContext` wire record. The messaging assembly owns `EventIdentifier`, schema identity validation, the event marker and a BCL-only `EventEnvelope` with UTC occurrence time, trusted producer, explicit scope, correlation/causation, content type and optional bounded W3C trace snapshot.

Wire records deliberately expose only Guid/string/int/DateTimeOffset fields. Strong helper types validate construction and canonical text but are not nested into the public wire shape. This keeps the schema language-neutral and satisfies the LayerGuard payload allowlist.

## Governance and compatibility

[`context-protocol-v1.json`](../../gates/G05/context-protocol-v1.json) freezes required/optional fields, canonical identity rules, unknown-field behavior and parallel-major requirements. The sole G03 catalog now admits both protocol projects with owner, consumers, BCL types, serialization and compatibility policy; its generated LayerGuard input is hash-bound and deterministic.

The protocol suite passed 27/27 tests for non-empty and canonical identifiers, tenant/platform discrimination, minimal BCL-only shapes, UTC time, schema identity, producer, traceparent and invalid combinations. The full solution passed 961/961 tests with zero build errors, and LayerGuard passed 179/179 with no new baseline violation. The 20 pre-existing package/nullability/obsolete-endpoint warnings remain visible. Real Plan 01 Contract adapters and Plan 02 Event carriers remain explicitly outside this phase.
