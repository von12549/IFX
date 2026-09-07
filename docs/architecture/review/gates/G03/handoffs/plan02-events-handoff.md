# G03 -> Plan 02 reliable Integration Events handoff

## Accountability and revisit

- Recorded accountable owner: `xiaolong-feng` / repository handle `@von12549`, acting for Registry,
  Transaction, Holdings, Platform Messaging, and the repository-maintainer roles in the catalog.
- Delivery owner: Plan 02 implementer, approved by the recorded accountable owner. The independent
  backup-owner slot is unassigned and remains a G03 closure blocker.
- Revisit trigger: the first PR that creates `IFX.Platform.Messaging.Contracts`, a V1 provider event,
  an Outbox/Inbox migration, or a Holdings inbound Adapter. Revisit before either event identity is
  promoted to Active and before the legacy unversioned event is removed.

## Authoritative inputs

- [`contract-event-catalog.yaml`](../contract-event-catalog.yaml) owns producer/consumer, identity,
  field purpose/classification, workflow/loop metadata, lifecycle, and legacy disposition.
- [`G03-serialization-golden.json`](../snapshots/G03-serialization-golden.json) is a pre-Active schema
  baseline and must be regenerated from real provider-owned source.
- [`shared-contract-primitives.md`](../shared-contract-primitives.md) freezes the target split:
  `IFX.Platform.Messaging.Contracts` is transport-neutral and BCL-only; bus, handler, serializer,
  dispatcher, broker, reliability, and DI belong to `IFX.Platform.Messaging.Runtime`.

Of 20 legacy Integration Events, 2 are Replace, 1 is Internalize, and 17 are Remove. The admitted
candidates are `ifx.transaction.transaction-processed.v1` and
`ifx.registry.class-status-changed.v1`, both consumed by Holdings and both Proposed.
`HoldingFrozenEvent` has no producer or consumer and must be removed.

## Required implementation and returned evidence

1. Create the BCL-only Messaging Contracts primitives and provider-owned immutable V1 schemas with
   stable wire names. Put trusted tenant/correlation/causation in the Gate 05-approved envelope.
2. Separate runtime bus/handler/DI concerns; module Contracts must not reference runtime or broker
   SDKs. Add dependency tests for the split.
3. Implement producer-local Outbox and consumer-local `(ConsumerId, EventId)` Inbox, deploy the
   Holdings consumer first, and prove commit-before-publish, at-least-once delivery, idempotency,
   quarantine, retry, replay, and loop termination.
4. Add provider/consumer serialization and behavior compatibility tests, regenerate golden
   snapshots from source, and reconcile registrations, producers, and handlers with the catalog.
5. Remove/internalize the other 18 event declarations as cataloged by 2026-12-01; preserve
   already-created V+1 messages during rollback.
6. Submit Change Records and Provider + Holdings Consumer + Platform/Architecture approvals. Only
   then request Active promotion and G03 Phase 6/9 re-evaluation.

An in-memory publish test or type registration without a durable path is not Active evidence.
