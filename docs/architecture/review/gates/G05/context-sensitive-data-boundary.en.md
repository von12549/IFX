# G05 Context and Sensitive Data Boundary

Status: PRE-READY (repository rules and conformance are complete; real Contract/Event carriers, production evidence, and approvals remain pending)  
Date: 2026-09-08  
Owner: xiaolong-feng

## Objective and authorities

This design separates business correlation, one operation, direct causation, event identity, technical trace, and tenant scope. It defines how those facts cross HTTP, synchronous Contract, Outbox, transport, Inbox, logging, metric, and audit boundaries. Headers, claims, payload fields, and log properties are not trusted facts; only an ingress Adapter establishes a trusted `ExecutionContext`.

The sole field-admission authority is the G03 `contract-event-catalog.yaml`. G05 schemas, policies, and tests consume that catalog and do not create a second field catalog. LayerGuard checks structure and dependencies; catalog/schema/runtime/security tests check field and value semantics.

## Architecture decisions

### G05-D01 — Identity semantics cannot be collapsed

`CorrelationId` identifies a business chain, `OperationId` the current unit of work, `CausationId` its direct parent, `EventId` an immutable logical event, and `RequestId` one Contract invocation. They use strong types, non-empty GUIDs, and canonical `D` text.

### G05-D02 — Only trusted Adapters establish ExecutionContext

HTTP, Contract provider, event consumer, scheduled job, dispatcher, and controlled management ingress create immutable context through explicit source policy. The `AsyncLocal` accessor stores only the current scope and prevents parallel tenant leakage through nested push/pop, `finally` cleanup, and detached-work suppression.

### G05-D03 — HTTP ingress fails closed

Public ingress creates internal correlation and W3C trace and does not adopt external correlation by default. Trusted gateway propagation requires explicit enablement and an exact allowlist. Every route declares Public, Tenant, or Platform scope; missing, malformed, duplicate, unauthorized tenant selection, or an administrator without explicit selection returns a stable error.

### G05-D04 — Synchronous Contracts carry minimum invocation context

The consumer Adapter creates a new `RequestId` per invocation, inherits correlation, uses the current operation as causation, and obtains source identity from configuration. The provider validates consumer, version, scope, actor/source, and tenant/resource before creating a child operation. Caller roles, permissions, and authorization conclusions are forbidden.

### G05-D05 — Event Envelope freezes logical identity

The producer captures EventId, UTC OccurredAt, producer, scope, tenant, correlation, causation, and bounded trace once from trusted runtime and ExecutionContext. Envelope and payload are immutable logical data; attempt, lease, next attempt, and last error are mutable delivery state. Unknown JSON fields may be ignored after required fields and version are validated.

### G05-D06 — Tenant and producer are validated before business execution

Event type, version, EventId, producer, tenant, correlation, and causation are validated in a fixed order before Inbox or Application. Producer and tenant errors are Security failures; other unrecoverable envelope errors are Permanent. Damaged technical trace restarts tracing without changing business context.

### G05-D07 — C0-C4 admission is purpose-minimal

Every public field records classification, purpose, consumer, requiredness, retention, log policy, and exception. C4 Secret is forbidden from Contracts, Events, and ordinary telemetry. C3 requires a controlled exception with owner, approver role, expiry, compensating controls, and revocation condition; unapproved or expired exceptions fail.

### G05-D08 — Operational telemetry and security audit are separate

Ordinary logging uses a central allowlist: C2 becomes keyed-HMAC pseudonym with key ID, C3 is redacted, C4 is dropped, and unknown fields default to redaction. Exception message/data/stack, bodies, SQL parameters, and provider responses never reach the ordinary sink. Security audit has separate writers/readers, append-only/tamper evidence, retention/deletion, and purpose-bound query.

### G05-D09 — Failure, replay, and compatibility are explicit

Diagnostic, Client, Business, Transient, Permanent, and Security each have one disposition. Retry and replay retain logical bytes and EventId; a completed Inbox still deduplicates. Forced work uses a separate approved `ReprocessingRequest`. A Compatibility Adapter registers owner/source/allowed fields/metric/expiry, may synthesize correlation and causation only, and marks provenance `synthesized`.

### G05-D10 — One verification entry point without premature production claims

Local and CI both run `scripts/Invoke-G05Verification.ps1`, composing the G03 validator, migration safety, G05 guard, LayerGuard, solution build/test, and TRX summary. Passing means repository conformance only; Plan 01/02, LayerGuard 03-A1, production telemetry, and approvals remain closure conditions.

## Terminology and lifecycle

| Term | Creator | Lifetime | Propagation rule |
|---|---|---|---|
| CorrelationId | HTTP or controlled root ingress | Whole business chain | Inherited by Contract/Event |
| OperationId | Each work-unit ingress | One HTTP/Contract/Event handler | Source of downstream causation |
| CausationId | Child-work creator | Current call/message | Direct parent operation or EventId |
| EventId | Event producer | Immutable logical event lifetime | Preserved across retry/replay |
| RequestId | Contract consumer Adapter | One invocation | Never reused; not the business chain |
| TraceId/SpanId | Tracing runtime | Technical observation chain | May restart; never replaces business IDs |
| TenantScope | Trusted ingress Adapter | Current execution scope | Never inferred from payload or leaked across parallel scopes |
| PlatformScope | Controlled management ingress | Current controlled operation | Never disguised as tenant scope |

### Forbidden substitutions

| Forbidden practice | Reason |
|---|---|
| Use TraceId as CorrelationId | Sampling/restart changes the technical trace |
| Use CorrelationId as OperationId/EventId | It cannot identify a work unit or idempotency key |
| Select tenant from payload/query/unvalidated claim | Cross-tenant authorization risk |
| Generate a new EventId on retry/replay | Breaks Inbox idempotency and audit chain |
| Copy caller roles/permissions into Contract/Event | Authorization conclusions cross a trust boundary |
| Put exception/body in dead-letter diagnostics | Creates a sensitive-data bypass |

## Current and target architecture

The current code has trusted HTTP/ExecutionContext foundations and conformance primitives, but legacy Readers/in-memory events remain and there is no durable messaging capability:

![Current context boundary](diagrams/current-context-boundary.svg)

The target uses consumer-owned Ports, provider Contract Adapters, module-owned Outbox/Inbox, pre-Inbox validation, and a central telemetry boundary:

![Target context boundary](diagrams/target-context-boundary.svg)

## Critical flows

Identity creation and validation from HTTP through Application and synchronous Contract:

![HTTP and Contract flow](diagrams/http-contract-flow.svg)

Target Event producer, Outbox, transport, Inbox, and downstream event flow:

![Event context flow](diagrams/event-context-flow.svg)

Trust-boundary and tenant selection must fail closed:

![Tenant trust decision](diagrams/tenant-trust-decision.svg)

Failure, bounded retry, quarantine, replay, and forced reprocessing states:

![Failure and replay state](diagrams/failure-replay-state.svg)

## Failure matrix

| Class | Retry | Action | Example |
|---|---:|---|---|
| Diagnostic | No | Continue with safe diagnostic | damaged trace restarted |
| Client | No | Reject request | invalid Contract context |
| Business | No | Complete with business result | business rule rejected |
| Transient | Bounded | Change delivery state only | transport unavailable |
| Permanent | No | Quarantine/dead-letter + alert | unsupported schema version |
| Security | No | Quarantine + audit + alert | invalid producer/tenant |

## C0-C4 admission matrix

| Class | Contract/Event | Ordinary log | Trace/Baggage/Metric | Security audit |
|---|---|---|---|---|
| C0 Public | Admit with real consumer | allowlisted raw value | bounded raw value | by purpose |
| C1 Internal | Admit minimum necessary | allowlisted raw value | low cardinality only | by purpose |
| C2 Confidential | Requires purpose/consumer/retention | keyed-HMAC pseudonym | no raw high-cardinality value | controlled reference |
| C3 Restricted | Controlled unexpired exception only | redact | drop | separate sink and controlled query |
| C4 Secret | Forbidden | drop | drop | do not retain credential material |

C2/C3 Amount, Units, NAV, and KYC data require the cataloged projection purpose, encryption, access, retention, deletion, and replay policy. Name, AccountNumber, Code, free-text reason, and duplicate TenantId default to removal or a capability-specific surface.

## Operations and remediation rules

- Production pseudonymization requires an external 256-bit key and key ID; missing configuration fails startup and rotation cannot recover source values.
- Request logs use route identity, not raw path/query; SDK errors map to stable codes.
- Quarantine/dead-letter logical bytes are separate from safe metadata; diagnostics exclude payload, raw headers, identifiers, and exception prose.
- Compatibility Adapter `legacy-event-correlation-v1` expires on 2026-12-01 and then fails closed; extension cannot bypass owner/approval.
- The Auth token-retention migration is authorized as a repository artifact only; production execution still requires database security approval, a restore point, and proof that old runtimes no longer write the columns.

## Rule-to-verification mapping

| Decision | Owner | Code/policy | Catalog/schema | Automated verification | Metric/manual evidence |
|---|---|---|---|---|---|
| D01 | Platform | Context strong IDs | context protocol | ProtocolContracts | context validation |
| D02 | ApiHost/Platform | ExecutionContextAccessor | source policy | accessor tests | scope cleanup |
| D03 | ApiHost | HTTP middleware | route scope policy | HTTP boundary tests | tenant rejection |
| D04 | Plan 01 | ContractRequestContext | G03 Contract entries | Contract conformance | real carrier pending |
| D05 | Plan 02 | EventEnvelope | V1 schema/golden | event conformance | real Outbox pending |
| D06 | Plan 02 | pre-Inbox policy | failure policy | failure matrix tests | producer/tenant metrics |
| D07 | G03/Security | field catalog | sole G03 validator | 13 mutation tests | C3 approvals |
| D08 | Security/Ops | redactor/sink policy | observability policy | sentinel tests | production attestations pending |
| D09 | Plan 02/Ops | replay/compat policy | adapter registry | replay/expiry tests | audit/alert pending |
| D10 | Architecture | unified script/workflow | verification baseline | G05 + LayerGuard + TRX | final approvals pending |

## Security review and remaining conditions

Repository C4 exposure is blocked, Auth secret columns have a roll-forward deletion migration, and ordinary telemetry sentinel tests pass. Eight C3 exceptions remain Pending/PendingRemoval and are not approvals. Production pseudonym key, sink ACL, retention/deletion, tamper evidence, audit-query, real alert, and migration-execution evidence remain pending.

This design is PRE-READY. Final closure requires Plan 01 real Contract carriers, Plan 02 durable Outbox/Inbox/Dispatcher/quarantine/replay, LayerGuard 03-A1 direct policy binding, the G04 runtime handoff, and approvals from architecture, module, Platform, security, and operations owners.
