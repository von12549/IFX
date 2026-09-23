# G03 Contract / Event governance baseline

> Status: PRE-READY, not closed. Four Plan 01/B2 and Plan 02/B3 protocols are
> `Active`; two later synchronous protocols remain `Proposed`. Final multi-owner
> approval is still open. This document explains the authoritative
> [`contract-event-catalog.yaml`](contract-event-catalog.yaml), which owns current facts.

## Boundaries and responsibilities

| Role | Owns | Does not own |
| --- | --- | --- |
| Provider Contract | Provider-named minimal capability, request/response semantics, stable identity | Consumer use case, data access, transport, or DI |
| Consumer Port | Business-shaped need and failure semantics owned by the consumer Application | Provider models or transport details |
| Integration Adapter | Maps a consumer Port to a Provider Contract, or an Event Envelope to an inbound command | Business decisions |
| Event owner | Committed business fact, schema, occurrence point, version, and production | Consumer projection or cross-module ACID |
| Application | Implements provider capabilities and orchestrates consumer-owned use cases and Ports | Direct foreign Contract, broker, or serializer dependencies |
| Composition | Wires implementations, Ports, and Adapters at the module boundary | Business logic or a new public protocol |

The synchronous dependency direction is
`Consumer.Application -> Consumer.Port <- Consumer.Adapter -> Provider.Contract`; the provider
Application implements the Contract. Asynchronously, a producer-owned schema travels through the
Outbox/transport to a consumer-owned inbound Adapter/Inbox. The overview includes synchronous,
asynchronous, and mixed workflows: [SVG](diagrams/provider-consumer.svg) ·
[PNG](diagrams/provider-consumer.png) · [Mermaid](diagrams/provider-consumer.mmd).

## Current public surface and target

The 2026-09-08 migration baseline had 46 legacy public items: 4 Readers, 15 Reader methods,
7 DTOs, and 20 Integration Events, with 20 `Internalize`, 6 `Replace`, and 20 `Remove`
dispositions. All 46 are now `Retired` in the catalog. The 2026-12-01 date was the original
migration deadline, not a count of work still pending. `HoldingFrozenEvent` had neither
producer nor consumer and was not promoted.

<!-- G03-CURRENT-PROTOCOLS-START -->
| Target identity | Mode | Provider -> Consumer | Status | Downstream owner |
| --- | --- | --- | --- | --- |
| `crm.account-compliance.v1` | sync | CRM -> Transaction | Active | Plan 01/B2 |
| `registry.class-subscription-availability.v1` | sync | Registry -> Transaction | Active | Plan 01/B2 |
| `ifx.transaction.transaction-processed.v1` | event | Transaction -> Holdings | Active | Plan 02/B3 |
| `ifx.registry.class-status-changed.v1` | event | Registry -> Holdings | Active | Plan 02/B3 |
| `auth.resource-authorization.v1` | sync | Auth -> CRM, Registry, Transaction, Holdings | Proposed | IAM/Authorization |
| `authorization.policy-evaluation.v1` | sync | Authorization -> IAM | Proposed | IAM/Authorization |
<!-- G03-CURRENT-PROTOCOLS-END -->

An identity becomes Active only after physical `Contracts.V1` source, public API/serialization
snapshots, provider and consumer behavior tests, catalog reconciliation, and approvals all exist.

### Module capability and data ownership

| Module | Owned capabilities | Owned data facts |
| --- | --- | --- |
| Auth | identity, authentication, subject/external mapping | identity subjects, credentials, external identity mappings |
| CRM | party, investor, investment-account, account-compliance | party, investor, investment account, KYC/compliance |
| Registry | product, fund, fund-class, subscription availability | product, fund, fund class, subscription status |
| Transaction | order, transaction-processing | order instruction, transaction lifecycle |
| Holdings | position, holding-freeze | holding, position, freeze state |
| Platform Messaging | schema primitives, runtime delivery | envelope semantics, delivery attempt state |

A shared process or physical database does not change ownership; a consumer cannot bypass provider
Application to read a foreign schema. `IFX.Platform.Messaging.Contracts` contains only BCL-only
schema primitives. Runtime bus, handler, serializer, dispatcher, broker, and DI concerns belong
to `IFX.Platform.Messaging.Runtime`. Both projects now physically exist; their admission and
dependency boundaries remain guard-enforced. See
[`shared-contract-primitives.md`](shared-contract-primitives.md).

## Lifecycle and migration

A normal protocol advances `Proposed -> Active -> Deprecated -> Retired`; a Retired identity remains
reserved forever. Legacy surface must be Internalized, Replaced, or Removed before its deadline.
State and migration diagram: [SVG](diagrams/lifecycle-migration.svg) ·
[PNG](diagrams/lifecycle-migration.png) · [Mermaid](diagrams/lifecycle-migration.mmd).

An external consumer records its owner, evidence, and `lastConfirmedAt` and is reconfirmed at least
every 90 days. A stale confirmation alerts and blocks retirement but never silently deletes the
consumer. Retirement also requires all consumers migrated, two successful production releases,
30 calendar days, zero old traffic, and no old-schema backlog/dead-letter/replay liability.

## Compatibility decisions and V1/V2

Decision flow: [SVG](diagrams/compatibility-decision.svg) ·
[PNG](diagrams/compatibility-decision.png) · [Mermaid](diagrams/compatibility-decision.mmd).

- Compatible: an optional field with a C# construction default, an enum value with tested fallback,
  or a documentation clarification with no semantic change.
- Conditional: validation/freshness/timeout tightened within a documented range, or an optional
  field whose fallback evidence still needs review.
- Breaking: remove/rename, type or meaning change, optional-to-required, interface or stable error
  code change, or a change to an event fact or occurrence point.
- Internal: implementation-only change outside the public schema and observable protocol.

A Breaking change publishes V+1 beside V, switches consumers at their own Adapters, observes both,
and retires the old version only after the retirement conditions pass. It never mutates an Active
identity in place. Sequence: [SVG](diagrams/v1-v2-migration.svg) ·
[PNG](diagrams/v1-v2-migration.png) · [Mermaid](diagrams/v1-v2-migration.mmd). Rollback keeps V1 and
the Adapter switch point and does not abandon V2 messages already created.

## Change, approval, and examples

Approval flow: [SVG](diagrams/change-approval.svg) · [PNG](diagrams/change-approval.png) ·
[Mermaid](diagrams/change-approval.mmd). Use
[`contract-change-record.md`](templates/contract-change-record.md) for every public change and
[`breaking-version-migration.md`](templates/breaking-version-migration.md) for a Breaking migration.

Minimal catalog example (fields are illustrative; the catalog schema is authoritative):

```json
{
  "identity": "crm.account-compliance.v1",
  "kind": "sync",
  "lifecycle": "Proposed",
  "provider": "crm",
  "owner": "xiaolong-feng",
  "consumers": ["transaction-application"]
}
```

A Change Record supplies classification, provider owner, affected consumers, compatibility
evidence, release order, rollback, and status. A waiver supplies rule, owner, reason, mitigation,
createdAt, expiresAt, and milestone. Expiry is the earlier of 90 days or the milestone. Missing
owner/consumer, internal-model exposure, C4, unapproved C3, and identity reuse are unwaivable.
Approved C3 State Transfer is controlled admission, not a waiver.

An external consumer example uses `kind=external-service`, a contact owner, auditable evidence,
and a `lastConfirmedAt` no more than 90 days old; loss of contact never deletes the entry. A shared
primitive request proves identical semantics in at least three modules or a required uniform
infrastructure protocol and supplies an owner, canonical serialization, compatibility policy, and
approvals from every affected module.

## Rule-to-evidence map

| Rule | Catalog validator | Snapshot / contract test | LayerGuard | CI | Manual approval |
| --- | --- | --- | --- | --- | --- |
| Unique, complete identity, owner, consumer, lifecycle | Yes | Active admission tests | ownership graph | G03 guard | Provider + Consumer |
| Field purpose, C0-C4, no C4 | Yes | golden serialization | schema dependency | G03 guard | C3/sensitive review |
| BCL-only and shared primitive allowlist | Yes | public API snapshot | framework/leak rules | handoff drift | Platform + Architecture |
| Compatible/Conditional/Breaking classification | Change Record reconciliation | API/schema diff + behavior | declaration/dependency support | snapshot drift | classification reviewer set |
| V+1, Deprecated, and Retired conditions | lifecycle validation | dual-version provider/consumer tests | no identity reuse | source reconciliation | all consumers + Architecture |
| Waiver expiry and unwaivable categories | Yes | negative self-tests | generated waiver input | blocking | owner + rule approver |
| External consumer 90-day confirmation | Yes | usage/traffic evidence | in-repo dependency graph | stale alert/block retire | external owner + Provider |

The automation entry point is `docs/guards/V3_ifx/commands/Invoke-IFXGuardrails.ps1 -Mode Specialized -SpecializedGate G03`. Phase 8 additionally checks
bilingual identity consistency, links, Mermaid/SVG/PNG triplets, and PNG signatures. Plan 03
L5.1 returned direct LayerGuard consumption, and Plans 01/02 returned Active evidence for the
original four protocols. The two later sync protocols and G03-6.5/6.6 closeout remain open.
The backup owner was assigned on 2026-09-08; this Gate remains PRE-READY until the remaining
technical conditions and closure approvals are satisfied.
