# G03 shared Contract primitives and migration handoff

`IFX.Platform.Messaging.Contracts` is a proposed BCL-only, transport-neutral schema project. It may
hold only the integration-event marker, stable schema identity, and the Gate 05-approved immutable
Event Envelope/value primitives listed in the governance catalog. It contains no dispatch or
delivery behavior.

`IIntegrationEventBus`, `IIntegrationEventHandler<T>`, serializer/dispatcher/broker ports and
implementations, delivery state, metrics, health, and DI registration remain runtime concerns.
Module Contracts must never reference that runtime project. The current
`IFX.Platform.Messaging.Abstractions` mixes these concerns and is therefore a migration input, not
the target project.

Contract projects default to BCL only. A sync protocol may additionally reference the Gate
05-owned `IFX.Platform.Context.Contracts` solely for call metadata. An event schema may reference
`IFX.Platform.Messaging.Contracts` solely for schema primitives. Domain/Security/Application
types, `Result<T>`, EF, MediatR, ASP.NET, DI, serializer/broker SDKs, handlers, and dispatchers are
denied.

Shared admission requires either identical semantics in at least three modules or necessity for a
uniform infrastructure protocol, plus a stable owner, canonical serialization, and compatibility
policy. Catalog validation rejects any incomplete entry.

## Build-green migration order for Plans 01/02

1. Add empty BCL-only `IFX.Platform.Messaging.Contracts` and its dependency tests.
2. Add the cataloged marker/identity/envelope primitives and golden tests from Gate 05.
3. Add provider-owned `*.Contracts.V1` schemas referencing only admitted primitives.
4. Move bus/handler interfaces to the runtime project; add temporary forwarding adapters if
   needed to preserve compilation.
5. Move consumer handlers into inbound Integration Adapters and switch Composition registrations.
6. Remove module references to Messaging Abstractions, then remove the mixed project after source
   reconciliation is clean.
7. Return real source, API/schema snapshot, and compatibility evidence to promote Proposed entries.

This phase does not claim those physical steps are implemented; they are owned by Plans 01/02.
