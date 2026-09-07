# G01 Module-local transaction boundary

> Status: the G01 core is implemented; final real Outbox/Inbox acceptance awaits Plan 02 E2/E4.
> Chinese version: [transaction-boundary.zh-CN.md](transaction-boundary.zh-CN.md)
> Decision record: [ADR-G01-001](ADR-G01-001-transaction-executor-split.md)

## 1. Goal and current change

G01 replaces the five modules' 15 pipeline behaviors with one host pipeline: Logging → Validation → Transaction. All 89 writes declare their owner through `ICommand<TResponse, TOwner>`; the shared `TransactionBehavior` resolves exactly one keyed executor for that owner. Handlers no longer perform final `SaveChangesAsync`, catch all exceptions, publish to transport, or send nested commands.

| Before | Target implementation |
| --- | --- |
| Infer writes from the `*Command` suffix | Typed `ICommand<TResponse, TOwner>` protocol |
| Register three behaviors in every module | Register each once in ApiHost, in a fixed order |
| Handler saves and publishes before commit | Behavior saves after success; transition dispatcher runs after commit |
| Any normal return commits | Only `IOperationResult.IsSuccess == true` commits |
| Handler catches every exception | Only explicit business exceptions are converted |
| UnitOfWork exposes transaction control | EF transactions exist only in module Infrastructure executors |

See the [architecture Mermaid source](diagrams/target-architecture.mmd) and [SVG](diagrams/target-architecture.svg).

## 2. Ownership and profiles

- `DeferredWrite` (default): run the handler first. A failure clears tracked changes and pending facts. On success, an execution strategy wraps Begin → participant prepare → one Save → Commit. Transient retries never rerun the handler.
- `Inbox`: begin before deduplication and the handler. The participant seam puts completion and business changes in the same save. E4 supplies the real `(ConsumerId, EventId)` entity, constraint, and adapter.
- `ConsistentReadWrite`: reserved for a small set of local consistent reads and writes. Network calls, another module, and a second DbContext are forbidden inside the transaction.

Each `TOwner` has exactly one keyed `ITransactionExecutor` in its module Infrastructure. Zero or multiple candidates fail before the handler with `TransactionOwnerResolutionException`. `TransactionScope`, cross-module enlistment, and a shared messaging DbContext are forbidden.

See [Deferred Write Mermaid](diagrams/deferred-write.mmd) / [SVG](diagrams/deferred-write.svg) and [Inbox Mermaid](diagrams/inbox-consumer.mmd) / [SVG](diagrams/inbox-consumer.svg).

## 3. Result, exception, and cancellation semantics

| Condition | Transaction action | API semantics |
| --- | --- | --- |
| Validation failure | No handler and no executor resolution | Structured field-error 400 |
| `Result.Failure` | No save; discard tracked state | Stable business response |
| `ForbiddenException` | Roll back/discard and propagate | 403 |
| Optimistic concurrency | Roll back and translate to `ConcurrencyConflictException` | Safe 409; retry after reload |
| Unexpected exception | Roll back/discard and propagate | Safe 500 without internal details |
| Cancellation | Roll back with an independent five-second cleanup token; preserve cancellation | Not logged as an ordinary error |
| Unknown commit outcome | Never claim rollback; reconcile by idempotency identity | Safe 503; no blind retry |

A rollback-cleanup failure is diagnostic only and never replaces the original exception. See the [failure-state Mermaid](diagrams/failure-states.mmd) / [SVG](diagrams/failure-states.svg).

## 4. Concurrency, uniqueness, and idempotency

Transaction, Order, Holding, Fund, and FundClass are high-contention aggregates. Infrastructure translates EF optimistic-concurrency failures into a stable non-EF 409 conflict. Database composite unique constraints must ultimately enforce tenant-scoped business keys; Application pre-checks only improve messages.

Commands that a client or infrastructure may retry implement `IIdempotentCommand<TResponse, TOwner>` and carry a stable key. The canonical identity is `(TenantId, CommandType, IdempotencyKey)`. It is stored in the owning module's own-schema `IdempotencyRecords` and committed atomically with the business change. Retention is at least seven days, or longer when the maximum client retry/reconciliation window requires it. An unknown commit outcome must be reconciled by this identity before retry; blind replay is forbidden. Consumers use `(ConsumerId, EventId)` as the Inbox unique identity, while EventId does not replace a consumer business key. The G01 reference fixture verifies these constraints; E4 owns the real Inbox schema, migration, and cleanup.

## 5. Outbox/Inbox seams and transition

`ITransactionParticipant.PrepareAsync` is the stable seam that places business data and pending/completion records in one `SaveChanges`. `ICommittedEventBuffer` records facts and exposes no transport operation. Its in-memory implementation dispatches only after local commit and propagates consumer failures, eliminating pre-commit notification.

The buffer is transitional. Plan 02 E2 owns its removal by 2026-12-31 or the E2 rollout, whichever comes first. It has no crash recovery and is not a reliable Outbox. E2 must attach module-local Outbox entities/migrations through the participant seam. E4 must attach metadata, Inbox deduplication, and completion through the `Inbox` profile and rerun the same conformance suite. Transport acknowledgement occurs only after the consumer transaction commits.

## 6. Correct use and forbidden patterns

```csharp
public sealed record CreateThingCommand(Guid TenantId)
    : ICommand<Result<ThingDto>, RegistryTransactionOwner>;

public async Task<Result<ThingDto>> Handle(CreateThingCommand command, CancellationToken ct)
{
    var thing = Thing.Create(command.TenantId);
    _unitOfWork.Things.Add(thing);
    _eventBuffer.Add(new ThingCreatedIntegrationEvent(thing.Id));
    return Result<ThingDto>.Success(Map(thing));
}
```

Command handlers must not call `SaveChangesAsync`, Begin/Commit/Rollback, `PublishAsync`, MediatR `.Send`, raw SQL, or `catch (Exception)`. Transaction owners must not be inferred from names, namespaces, or attributes. A shared Outbox/Inbox DbContext is prohibited.

## 7. Rule-to-evidence map

| Rule | Automated evidence |
| --- | --- |
| Command markers; no final save, catch-all, direct publish, or nested send | `scripts/Invoke-G01TransactionBoundaryGuard.ps1` |
| Success/failure/exception/cancellation, profiles, retry without handler replay, post-commit dispatch | `IFX.BuildingBlocks.Application.Tests` |
| Relational commit/rollback/savepoint/concurrency, Inbox/idempotency uniqueness, commit-response-lost reconciliation | `IFX.BuildingBlocks.EntityFrameworkCore.Tests` |
| Unique behavior registration/order and actual isolation calls for five module executors | `ApplicationPipelineCompositionTests` against the real ApiHost |
| Structured 400, 403, safe 409/500, cancellation logging | `ExceptionHandlingMiddlewareTests`, `ExceptionHandlingHttpEndToEndTests` |
| Layer and cross-module references | `scripts/Invoke-LayerGuard.ps1 -Mode B0.5` |
| Real Outbox/Inbox atomicity, uniqueness, and crash windows | Plan 02 E2/E4 (open) |

See [G01-baseline.md](../../evidence/gates/G01/G01-baseline.md), the [G01 closeout evidence](../../evidence/gates/G01/G01-closeout.md), and the latest [G01-guard-report.json](../../evidence/gates/G01/G01-guard-report.json).
