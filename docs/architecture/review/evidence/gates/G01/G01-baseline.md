# G01 transaction-boundary baseline

Captured from commit `fe635fc` on 2026-09-07 before the G01 migration.

## Source snapshots

- The five module-local `TransactionBehavior` implementations lived under each module's `Application/Behaviors` directory. Each selected a transaction from the request type name and committed after any normal handler return.
- `ProcessTransactionCommandHandler` persisted with `SaveChangesAsync`, synchronously called `PublishAsync`, and then returned; the outer behavior committed afterward.
- `InMemoryIntegrationEventBus` invoked consumers synchronously and logged consumer exceptions without propagating them.
- The shared ApiHost received 15 open generic pipeline registrations: five each for Logging, Validation and Transaction.

The immutable source snapshot is the Git tree at `fe635fc`; the paths above can be reproduced with `git show fe635fc:<path>`.

## Migration inventory

| Check | Baseline | G01 target |
| --- | ---: | ---: |
| Command handlers | 89 | 89 |
| textual `SaveChangesAsync` occurrences | 90 | 0 active calls |
| catch-all occurrences | 90 | 0 |
| direct `PublishAsync` occurrences | 23 | 0 |
| nested `.Send` occurrences | 1 | 0 |
| module-local shared behaviors | 15 | 0 |
| open generic shared behavior registrations | 15 | 3 |

The earlier planning estimate stated 88 handlers with final saves. The reproducible Git-tree scan found 90 textual occurrences: 89 active final saves plus one commented call in `SyncUserCommandHandler`. G01 uses the reproducible scan and separately ignores comments in the post-migration guard.

## Special-path characterization

- No active raw SQL was found in Command handlers.
- `ResendEmailVerificationCommandHandler` nested `SendEmailVerificationCommand` through MediatR; shared issuance logic therefore required extraction to an Application service.
- Handlers publishing integration events had a commit-order hazard because the in-memory consumer ran before the producer transaction committed.
- Database-generated identifiers remain assigned by aggregate creation; no migrated handler requires an intermediate save to obtain an identifier.

## Reproduction

Run `scripts/Invoke-G01TransactionBoundaryGuard.ps1` against the migrated tree. For a historical comparison, enumerate the same patterns from `fe635fc` with `git show` or `git grep` without checking out the old tree.
