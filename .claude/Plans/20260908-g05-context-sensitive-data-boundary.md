# G05 context-sensitive data boundary implementation

Date: 2026-09-08

## Objective

Implement `docs/architecture/review/plans/00-G05-context-sensitive-data-boundary.md` phase by phase. Establish transport-neutral context and envelope primitives, trusted execution scopes, fail-closed tenant handling, field classification and safe observability without prematurely claiming the real Plan 01 Contract or Plan 02 Outbox/Inbox implementations.

## Sequence

1. Phase 0 — generate a deterministic, value-free inventory of context, tenant, protocol, logging, error and secret-retention surfaces.
2. Phase 1 — add BCL-only strong identifiers, execution scopes, actor/source references, Contract request context and Event Envelope V1 primitives.
3. Phase 2 — add an immutable execution-context accessor with scoped push/pop/finally semantics and composition ownership.
4. Phase 3 — establish HTTP correlation, W3C trace and fail-closed tenant context before Application execution.
5. Phase 4 — create transport-neutral Contract context construction/validation conformance.
6. Phase 5 — create Event Envelope schema and fake Outbox/carrier/Inbox propagation conformance.
7. Phase 6 — extend the single G03 catalog with field classification, purpose, consumer and retention governance.
8. Phase 7 — enforce safe logging, trace, metric and error behavior; resolve or explicitly block on C4 token persistence.
9. Phase 8 — codify failure, quarantine, replay and expiring compatibility rules.
10. Phase 9 — provide one local/CI verification entry point linking catalog, schema, runtime, security and LayerGuard reports.
11. Phase 10 — publish bilingual, rendered architecture and rule-to-evidence documentation.
12. Phase 11 — record a truthful PRE-READY handoff until Plan 01/02, LayerGuard policy binding, production security evidence and approvals return.

## Phase discipline

- Preserve the current branch and unrelated changes; do not push.
- Complete targeted verification, solution build/tests, G05 guard and LayerGuard at each material phase.
- Keep sensitive values out of generated inventory and evidence. Record only source locations, schema names and classifications.
- Gate 05 does not own final module Contract migration, durable Outbox/Inbox/Dispatcher, broker, dead-letter or replay engines.
- Mark a checklist item complete only when repository evidence exists. Production, security-review and downstream evidence remains PRE-READY.

## Phase 0 acceptance

- G05-0.1 through G05-0.6 have deterministic repository evidence or a named external gap.
- Token persistence, identifier logging, unsafe tenant fallback and raw exception exposure have explicit owners, severity and resolution triggers.
- The inventory records that durable Outbox/Inbox/dead-letter/replay are not current capabilities.
- Solution build/tests, LayerGuard and the G05 Phase 0 guard pass with warning debt reported unchanged.

## Progress

- [x] Phase 0 — deterministic value-free context/security baseline.
- [x] Phase 1 — BCL-only Context and Messaging protocol primitives.
- [x] Phase 2 — immutable execution context lifetime, composition ownership and source rules.
- [ ] Phase 3 — HTTP trace, correlation and fail-closed tenant entry.

## Phase 2 acceptance

- Application exposes one transport-neutral immutable execution-context read port and one scope factory.
- Root composition owns the unique singleton-safe `AsyncLocal` implementation; no singleton field stores a current context value.
- Push/pop nesting, reverse disposal, exception/cancellation cleanup, parallel tenant isolation and detached-work suppression are tested.
- Auth HTTP identity facts and tenant selection are separate from `CurrentUser` orchestration.
- HTTP, scheduled job, dispatcher, message delivery and controlled management sources have explicit actor/source/scope builders and missing-context behavior.
- Solution build passed with 0 errors and the unchanged 20 warnings; 972/972 solution tests and 179/179 LayerGuard tests passed.
