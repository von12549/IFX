# P04-S5 — GOV3 owned projection policy

## Result

Repository validation is **passed** with the deliberately narrow result
`repository-passed-no-reporting-product-claimed`.

- No current or approved cross-module reporting/query consumer was found.
- Consequently, no public projection schema is registered or authorized.
- A cross-module read may use only a local versioned Contract or an approved,
  registered projection owned by the query use case.
- Cross-DbContext and cross-module table joins are forbidden, including as a
  fallback during projection failure or rebuild.

This result is architecture and repository evidence only. It does not claim a
production reporting product, reporting SLO, production acceptance, event
retention sufficiency, or approval for a future consumer.

## Ownership and registration

The query owner owns the projection store, schema and observable consistency
semantics. Source modules publish only the minimum versioned facts admitted by
G03; they do not expose their tables, `DbContext` or internal entities. A future
registration must identify the query owner, source data owner and consumer, and
must carry Architecture, Query Owner, Source Data Owner, Reporting/Data and
Security/Privacy approvals before its status can become `approved`.

The machine policy and schema are:

- [`cross-module-projection-policy.json`](../../policies/plan04/cross-module-projection-policy.json)
- [`projection-registration.schema.json`](../../policies/plan04/projection-registration.schema.json)
- [`projection-registry.json`](../../policies/plan04/projection-registry.json)

## Required semantics and lifecycle

Every future projection must define a versioned schema and tenant partition,
durable Inbox/idempotency, ordering decision, freshness objective and explicit
eventual-consistency API/UI behaviour. Registration also requires bootstrap,
backfill, full rebuild, incremental catch-up, checkpoint, reconciliation, drift
detection and source-retention dependencies.

Failure handling covers unavailable source and consumer, duplicate and
out-of-order events, poison messages, partial rebuild and incompatible schema.
Recovery retains the durable source and checkpoint, then rolls forward through
rebuild/catch-up; it never switches to a cross-database query.

G05 classification and minimisation apply to the projection independently.
Access, encryption, retention, deletion and logging must be stated, and a
projection cannot retain a sensitive superset or bypass tenant deletion.

## Holdings reference boundary

The existing Holdings consumers for
`ifx.transaction.transaction-processed.v1` and
`ifx.registry.class-status-changed.v1` are verified references for trusted
tenant propagation, durable delivery and `ConsumerId + EventId` Inbox
idempotency. They update Holdings-owned domain state. They are **not** an
approved cross-module reporting product and do not demonstrate reporting
bootstrap, rebuild, reconciliation, source retention or consumer acceptance.

## Automated evidence

Run:

```powershell
./scripts/Test-Plan04ProjectionPolicy.ps1
```

The validator binds the policy, schema, registry, G03 catalog and Plan 04
dependency graph hashes; reconciles the two Holdings protocols with Active G03
entries; inspects the tenant-envelope and Inbox implementation; rejects
forbidden physical edges and multiple module `DbContext` use; and exercises
positive plus five negative fixtures.

- [`cross-module-query-inventory.json`](cross-module-query-inventory.json)
- [`phase5-projection-status.json`](phase5-projection-status.json)

Negative evidence covers cross-DbContext/table join, unregistered projection,
duplicate business effect, rebuild drift and sensitive-field supersets. Missing
input or an unrecognised/invalid shape fails the validator rather than producing
a green report.
