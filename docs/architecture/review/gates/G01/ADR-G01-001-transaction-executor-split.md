# ADR-G01-001: Split transaction policy from module execution

- Status: Accepted
- Date: 2026-09-07
- Scope: G01 / TX1–TX5

## Context

Each module previously owned a copied pipeline behavior and exposed transaction control through its UnitOfWork. In a shared host this registered 15 open generic behaviors, allowed unrelated module transaction policies to observe one request, and left final persistence in handlers.

## Decision

The process-wide Application BuildingBlock owns `ICommand`, `IOperationResult`, transaction profiles, the three shared behaviors, and the narrow `ITransactionExecutor`/participant ports. A Command declares one module owner type. Module Infrastructure provides exactly one keyed executor for that owner and is the only layer that references EF transaction types. UnitOfWork remains a module persistence/repository port but exposes no Begin/Commit/Rollback API.

Default execution is Deferred Write. Inbox and Consistent Read/Write are explicit profiles. No profile permits cross-module ACID or ambient `TransactionScope`.

## Consequences

- The pipeline can decide commit from a stable result protocol without module branching or reflection.
- Handlers are simple use-case orchestrators and do not own final persistence.
- Retry can wrap only the persistence transaction and does not repeat handler side effects.
- Outbox/Inbox can attach module-local pending/completion records through participants.
- Every new module must define an owner and exactly one Infrastructure executor.
- E2/E4 remain responsible for real Outbox/Inbox entities, migrations, dispatch, deduplication, and relational acceptance tests.
