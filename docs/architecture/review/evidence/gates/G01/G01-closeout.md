# G01 closeout evidence

Date: 2026-09-07

G01's transaction policy, typed seams, handler migration, relational reference fixtures, host
composition, and automated guards are complete. Final production Outbox/Inbox acceptance remains
owned by Plan 02 E2/E4 and is intentionally not represented as complete here.

## TX1-TX5 evidence

| Requirement | Decision and code | Automated evidence | Status |
| --- | --- | --- | --- |
| TX1: one module-local ACID boundary | `ADR-G01-001-transaction-executor-split.md`; `ICommand<TResponse, TOwner>`; one keyed module executor | `ApplicationPipelineCompositionTests.Five_module_commands_call_only_their_keyed_executor` and LayerGuard | Complete |
| TX2: failure results never commit | `TransactionBehavior` checks `IOperationResult.IsSuccess` and discards/rolls back rejection | `TransactionBehaviorTests.Deferred_failure_discards_without_persisting_or_dispatching` and `Inbox_failure_rolls_back_semantically_and_does_not_dispatch` | Complete |
| TX3: exception, cancellation, transient retry, and cleanup semantics | `EfCoreTransactionExecutor`; `ConcurrencyConflictException`; `TransactionCommitOutcomeUnknownException`; host exception middleware | Application state matrix, EF fault injection/SQLite tests, and HTTP end-to-end tests | Complete |
| TX4: business data plus local Outbox seam | `ITransactionParticipant` joins pending records to the owning DbContext's one save; `ICommittedEventBuffer` dispatches only after commit | `Persistence_atomically_saves_business_and_pending_records`; G01 static guard prohibits handler transport publish | Seam complete; real Outbox E2 open |
| TX5: consumer data plus local Inbox seam | `TransactionProfile.Inbox`; `IntegrationEventMetadata`; `(ConsumerId, EventId)` conformance identity | `InboxProfileConformanceTests` covers atomic completion, rejection, duplicate, concurrent duplicate, and commit-response-lost reconciliation | Seam complete; real Inbox E4 open |

The full design and error-state table are in the Chinese and English G01 transaction-boundary
documents. The G01 guard report is machine-readable in `G01-guard-report.json`.

## Verification

- `dotnet build IFX.sln --no-restore`: succeeded, 0 errors (existing dependency warnings remain).
- `dotnet test IFX.sln --no-build --no-restore`: 811 passed, 0 failed, 0 skipped.
- `dotnet test mcp/LayerGuard/LayerGuard.slnx --no-restore`: 178 passed, 0 failed.
- G01 transaction guard: passed; 89 commands and 89 handlers, with zero missing markers,
  final saves, catch-all blocks, direct publishes, nested sends, or raw SQL violations.
- LayerGuard B0.5: `baseline-clean`; 116 matched, 0 new, 0 stale.
- `git diff --check`: passed; only line-ending conversion notices were emitted.

The scripted LayerGuard wrapper's final invocation could not read the sandboxed user-level
NuGet.Config. The already-built, already-tested LayerGuard 0.3.0-a0 binary was therefore invoked
directly with the identical source, policy, baseline, and report arguments; it returned exit code
zero and generated `G01-layerguard-report.json`.

## Deferred owners and waivers

| Item | Owner | Due/expiry | Removal or acceptance condition |
| --- | --- | --- | --- |
| Replace the process-local `ICommittedEventBuffer` transition with module-local durable Outbox | Plan 02 E2 | 2026-12-31 or E2 rollout, whichever is earlier | Real module entities/migrations pass the same atomic conformance suite and the transition buffer is removed |
| Bind real Inbox entities, migration, inbound adapter, and transport acknowledgement | Plan 02 E4 | E4 acceptance | `(ConsumerId, EventId)` unique constraint and business/completion atomicity pass against the module database |
| TX6 KYC/Class TOCTOU controls | Architecture plus Registry/Transaction Application owners | Follow-up transaction backlog | Reservation/version/expiry/compensation choice is documented and tested |
| TX7 cross-module Saga/compensation state machines | Architecture plus each owning module Application owner | Follow-up transaction backlog | State, timeout, compensation, manual intervention, and audit design is approved |
| TX9 Saga fault injection | Infrastructure and Test Engineering owners | After TX7 implementation | Compensation failure, timeout, and manual recovery tests pass |

There is no G01-specific LayerGuard debt waiver. The approved B0.5 policy/baseline decision and its
unchanged historical findings are recorded separately in `G01-layerguard-policy.md`.

## Rollback controls

- Roll back module-by-module only to a previously verified single transaction path; never enable
  old and new transaction behaviors for the same command.
- A rollback must not restore pre-commit integration-event notification. If unavoidable, record
  owner, impact, reconciliation, expiry, and re-entry criteria before deployment.
- Deploy concurrency/idempotency schema changes only after forward/backward compatibility and
  migration ordering are verified by the owning module.
- Every rollback record includes cause, affected data, reconciliation, owner, and the condition for
  re-enabling G01.

## Remaining closure conditions

- G01-9.3 / DD05: E2 and E4 must implement their real module-local bindings and pass the shared
  conformance expectations without creating another transaction policy.
- G01-9.6: Architecture, Application, and Infrastructure owners must jointly sign off the final
  Gate closure after the E2/E4 evidence is linked.

## Plan 02 / B3 return — 2026-09-08

Plan 02 has now returned the real E2/E4 implementation. Transaction and Registry own their Outbox
entities/migrations and attach pending logical messages through the existing
`ITransactionParticipant`; Holdings owns its Inbox/quarantine and executes through the existing
`TransactionProfile.Inbox`. No parallel Behavior, executor, or transaction protocol was added.

`Plan02ReliableMessagingSqlServerTests` proves successful business+Outbox commit, rollback with no
deliverable row, lease-expiry reclaim, stale-owner rejection, dead-letter/replay identity, and
Holdings business+Inbox apply-once behavior on SQL Server. See the
[B3 Gate handback](../../plan02/B3-gate-handback.md). G01-9.3/DD05 repository evidence is accepted;
only the named final Architecture/Application/Infrastructure signatures remain open.
