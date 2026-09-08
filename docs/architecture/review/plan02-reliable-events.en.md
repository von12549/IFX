# Plan 02 / B3: reliable Integration Events implementation baseline

> Status: the B3 repository implementation is complete; production alert calibration, the consumer-first rehearsal, and final Gate approvals remain open. See the [Chinese version](plan02-reliable-events.zh-CN.md).

## Implemented boundary

The repository admits only two provider-owned immutable V1 facts: Transaction's `ifx.transaction.transaction-processed.v1` and Registry's `ifx.registry.class-status-changed.v1`. Both live in provider Contracts and omit TenantId from the payload. Platform Messaging freezes trusted tenant, EventId, occurrence time, correlation/causation, and trace carrier into the Envelope when the Outbox row is created. All 20 legacy event declarations were removed and remain reserved as Retired historical identities in the G03 catalog. CRM KYC remains the synchronous Plan 01 Contract.

Transaction and Registry each own an Outbox in their DbContext and schema. The single G01 `TransactionBehavior` and `ITransactionParticipant` write the immutable logical message before the business transaction commits; rejection or rollback leaves no deliverable row. Mutable attempt, lease, next-attempt, error, and delivery state are physically separate from Envelope and payload fields.

The Dispatcher lives in `IFX.Platform.Messaging.Runtime`, while ApiHost may compose it only through `IFX.Platform.Messaging.Composition`. Only `worker` and `all` roles start it; `api` does not. Claims use SQL Server `UPDLOCK/READPAST/ROWLOCK`, a short transaction, unique owner, lease, and rowversion. Sending happens outside that transaction and completion/failure is conditional on the original lease. Errors flow into bounded exponential backoff with jitter and dead-lettering. A standard `System.Diagnostics.Metrics` meter publishes attempt/success/failure/dead-letter counters plus backlog age/count, retry, lease, expired-lease, and processing-rate gauges. A per-module readiness contributor evaluates the G04 warning/critical thresholds.

Holdings parses and validates external DTOs at its Infrastructure `Integrations` boundary. Before Application runs, the adapter validates producer, event type/version, and tenant scope, then creates an isolated ExecutionContext with EventId as OperationId and maps to a Holdings-owned command. Application references neither provider Contracts nor Runtime. `TransactionProfile.Inbox` performs deduplication, business mutation, and Inbox completion in one Holdings transaction, protected by the `(ConsumerId, EventId)` unique key. Invalid producer/tenant/payload and business rejection enter quarantine containing safe diagnostic fields only.

## Delivery and recovery semantics

Delivery is at-least-once. A crash after send but before completion can redeliver the same EventId, which the Inbox absorbs. A partition is claimable only when it has no earlier Pending row; no global ordering is promised. Dead-letter replay resets delivery metadata only and retains the original Envelope and payload. Diagnostic queries return EventId, type, tenant reference, timestamps, state, attempts, and bounded error code—never payload.

The current transport is in-process, creates a consumer scope, and propagates handler failures. A broker replaces only the Runtime sender boundary. Platform-scoped management endpoints expose metadata-only Outbox/Inbox diagnostics, replay preview, and replay execution. The three actions have separate permissions; replay is capped at 100 items, always audited, and fails closed unless the configured handler version is compatible. Production operators follow the [reliable-events runbook](runbooks/plan02-reliable-events.md) and never change EventId to bypass Inbox deduplication.

## Projection and data lifecycle

Class status is a safety projection in Holdings. Registry's `ClassStatusChangedV1` is the incremental authoritative fact, while Holdings write paths use only their local frozen state and avoid a cross-module TOCTOU read inside the local transaction. Bootstrap takes a bounded Registry snapshot with a checkpoint, then applies events after that checkpoint by EventId/order; restart resumes from the last completed Inbox marker. A rebuild writes a new projection version, reconciles counts and samples, atomically switches the read version, and deletes the old version only after the rollback window. If the projection is stale or health is critical, risk-bearing writes for Closed/Liquidating classes fail safe and reads may return a degraded result with freshness.

Downstream commands/events retain the original CorrelationId and use the inbound EventId as both consumer OperationId and next-hop CausationId. The Inbox unique key terminates duplicate chains; event types must not unconditionally republish each other. Outbox payloads contain only minimal C0-C2 facts, and diagnostics/audit never return payload. Payload, delivery metadata, Inbox, and quarantine follow each module's retention/deletion and legal-hold workflow. Subject-data deletion must account for the replay window; after expiry the payload or row is removed, while retained audit fields must not reconstruct sensitive business data. Production encryption, access groups, retention jobs, and deletion attestations remain deployment acceptance items.

## Data and security

Event payloads are at most C2 and contain no C4 value, name, account number, credential, or free-text error. Logs contain module, low-cardinality event type, EventId, and attempt—not payload. Outbox, Inbox, and quarantine inherit module database access, encryption, retention, and deletion controls. Trace data is technical correlation only and is never an authority for tenant or authorization.

## Verification and external conditions

Automation covers provider schema/golden, unknown-field compatibility, producer emission, business/Outbox atomicity, concurrent claim/partition ordering, all three crash windows, failure propagation, retry/dead-letter/replay identity, ordinary and concurrent Inbox deduplication, quarantine, context cleanup/downstream causation, authorized diagnostics, and end-to-end mapping. Relational cases use the standard SQL Server Testcontainers fixture.

B3 LayerGuard is 32 matched / 0 new / 0 stale under the governed Runtime ring and removes 71 historical findings from B2. B4 still owns removal of the remaining 32. Production capacity calibration, alert wiring, consumer-first release rehearsal, and final multi-owner Gate signatures remain explicitly open because repository code cannot self-attest them.

Diagrams: [implemented architecture](diagrams/plan02-reliable-events-architecture.svg), [normal sequence](diagrams/plan02-reliable-events-sequence.svg), and [failure/recovery](diagrams/plan02-reliable-events-recovery.svg).
