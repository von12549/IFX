# Plan 04 module boundaries, tenant queries, and owned projections

> Status: PRE-READY (repository implementation and verification passed; named functional approvals, production RLS, and real reporting acceptance remain open)
> 中文：[模块边界、租户查询与 Owned Projection](module-boundary-evolution.zh-CN.md)
> Execution plan: [Plan 04](plans/04-module-boundary-evolution.md)
> Evidence index: [Plan 04 evidence](evidence/plan04/README.md)

## 1. Decision summary

IFX remains a modular monolith. Auth, CRM, Registry, Transaction, and Holdings
own their capabilities, Domains, DbContexts, and schemas. A shared ApiHost,
Worker roles, physical database, and business release do not transfer that
ownership. The current decisions are `retain` for Auth, CRM, Registry, and
Holdings, and `narrow-edge` for Transaction. Transaction may consume CRM and
Registry versioned Contracts only through consumer-owned outer adapters; its
Application cannot reference foreign modules directly.

The four Active edges come only from the G03 catalog. CRM → Transaction and
Registry → Transaction are minimum synchronous decisions. Transaction →
Holdings and Registry → Holdings are versioned facts. The B4 project/namespace
graph and G03 protocol graph prove different properties and must both pass.

## 2. Granularity and extraction gates

Project count, fan-in/out, co-change, and common release are review signals,
not automatic split evidence. A Microservice candidate must pass all seven hard
gates: single business owner, single data owner, no shared ACID requirement,
versioned protocols, a known consistency model, an independent security
boundary, and a named operations owner. Scoring ranks eligible candidates and
cannot override a failed hard gate.

State advances only through controlled transitions in `retain → observe →
candidate → approved → executing → extracted`. Execution requires the relevant
Architecture, Module, Platform, Database, Security, and Operations approvals,
plus DP8 runtime/resilience and DP9 package-cadence designs. Insufficient
evidence falls back to the modular monolith, never shared DbContexts,
cross-module transactions, or weaker Contracts.

## 3. Trusted tenant-query boundary

An ordinary business Repository/Contract accepts a non-null `Guid tenantId`,
calls `TenantQueryGuard.Require`, and includes an explicit tenant predicate in
the EF query. The value comes from the trusted G05 ExecutionContext. Nullable,
default, implicit global tenant context, and ordinary-interface bypass flags are
forbidden. Explicit predicates are selected; EF global query filters are
`not-selected` because hidden context and background/migration bypasses would
reduce reviewability.

Cross-tenant administration has separate `AcrossTenants` interfaces and must
combine platform execution scope, a trusted actor, a platform-role allowlist,
a dedicated permission, purpose, structured audit, and a 500-row maximum. The
five registered Auth entries have an owner, expiry, and negative tests. SQL
Server RLS is `deferred-not-claimed` until production identities,
`SESSION_CONTEXT`, pool cleanup, Migrator and break-glass behaviour, performance,
and target-environment tests exist.

## 4. Cross-module reads and projection ownership

A cross-module query has only two legal paths: a local versioned Contract or an
approved, registered projection owned by the query use case. Source modules
publish minimum versioned facts; they do not expose tables, DbContexts, or
internal Entities. Cross-DbContext/table joins and cross-database failure
fallbacks are forbidden.

A future registration defines schema version, `TenantId` partitioning,
Inbox/idempotency, ordering, freshness, and eventual-consistency UI/API
semantics. It also defines bootstrap, backfill, rebuild, catch-up, checkpoints,
reconciliation, drift detection, and source-retention dependencies. Recovery
covers unavailable source/consumer, duplicates, out-of-order facts, poison,
partial rebuild, and incompatible schemas, retaining the durable source and
checkpoint and rolling forward.

G05 C0–C4 classification, minimisation, access, encryption, retention, deletion,
and logging apply independently. A projection cannot keep a sensitive superset
or bypass tenant deletion. There are currently zero approved reporting
consumers and zero public projection schemas. The two Holdings event consumers
are references only for tenant envelopes, durable delivery, and
`ConsumerId + EventId` idempotency. They update Holdings-owned domain state and
do not prove a reporting product, rebuild, retention, or consumer acceptance.

## 5. Automation, failure, and rollback

`docs/guards/V3_ifx/scripts/Invoke-IFXGuardrails.ps1 -Mode Specialized -SpecializedGate Plan04` runs the graph, GOV4, DP6, DB8, and GOV3 validators. V3 Architecture and HistoricalIntegrity independently bind current policy and frozen evidence.
Negative fixtures prove failure for unregistered edges, cycles, unknown owners,
hash drift, hard-gate bypass, missing tenant filters, unauthorized bypasses,
cross-DbContext access, duplicate effects, rebuild drift, and sensitive
supersets.

Phase 7 passed 1,108/1,108 solution tests and 189/189 LayerGuard tests, with 39
governed projects and zero violations. See the
[rule map](evidence/plan04/rule-validation-map.json) and
[diagrams](diagrams/plan04/README.md). Missing or drifting inputs stop the
decision and require regeneration and review; generated reports are never
edited to manufacture a green result.

## 6. Open closure work

Named GOV4 and DP6 functional approvals remain pending. Architecture, Module,
Platform, Database, Security, Operations, and Reporting/Data roles cannot be
self-approved by the code author. DB5–DB7, GOV6, OPS2/OPS5, and DP8/DP9 remain
in their own future scopes. This design therefore establishes repository
governance only, and the plan remains PRE-READY.
