# G02 closeout evidence

Date: 2026-09-08

G02's database ownership, migration history, legacy adoption, one-shot Migrator, compatibility
readiness, real SQL Server matrix, controlled rollout rehearsal and bilingual baseline are complete.
The Gate is PRE-READY, not finally closed. Plan 02 E2/E4 still owns the real module Outbox/Inbox
objects, and G04 owns the production Migrator → Worker → API orchestration evidence.

## DB1–DB4 and DB9–DB11 evidence

| Requirement | Decision and implementation | Automated/operational evidence | Status |
| --- | --- | --- | --- |
| DB1: module database ownership | `ADR-G02-001`; five DbContexts, schema constants and dedicated connection keys | `ModuleSchemaOwnershipTests`, G02 inventory/guard, LayerGuard | Complete |
| DB2: Auth migration identity and legacy states | Canonical `20260327075710_InitialCreate`, 14-ID legacy manifest, erroneous alias and full fingerprint adoption | Phase 3 report; Auth legacy and partial-state SQL Server matrix | Complete |
| DB3: schema-local histories | Each context configures its own `<schema>.__EFMigrationsHistory`; explicit bootstrap maps exact ownership | Phase 2 report; shared-history, idempotency, lock and rollback matrix | Complete |
| DB4: default-schema protection | Every DbContext calls its module `HasDefaultSchema`; mappings use schema constants | Model ownership tests plus database metadata assertions | Complete |
| DB9: controlled production migration mechanism | Independent `IFX.DatabaseMigrator`, manifest order, database application lock, structured modes/reports, roll-forward recovery | Phase 4/6 reports and Phase 8 containerized rehearsal | Complete mechanism; production execution belongs to G04 |
| DB10: deterministic container ordering | SQL healthy → init completed → Migrator completed → ApiHost; failed Migrator blocks API | Compose/NAS Compose plus Phase 5 orchestration tests | Complete for current API path; Worker production sequence belongs to G04 |
| DB11: relational migration matrix | SQL Server 2022 covers fresh, shared, legacy, partial, upgrade, concurrency, injected failure, rerun and split identities | Phase 7 matrix: 12/12; Phase 8 controlled target | Complete |

The design baseline is [English](../../../gates/G02/database-boundary.en.md) /
[中文](../../../gates/G02/database-boundary.zh-CN.md). Machine-readable gate reports and rollout records
are in this directory.

## G01 alignment

- One transaction owner maps to one module DbContext and therefore one module schema; no cross-module
  DbContext or distributed transaction is introduced.
- G01 `ITransactionParticipant` is the extension seam for E2/E4. The producer Outbox joins the
  business change in the producing module's save; the consumer Inbox joins the consumer change in
  the consuming module's save under `TransactionProfile.Inbox`.
- Outbox/Inbox tables and histories remain in the owning module schema. A shared Messaging DbContext,
  cross-schema FK and pre-commit transport publish are all forbidden.
- `G02SqlServerAssertions` is the relational callback seam for entity/table/schema/history/FK,
  fresh/upgrade, pending migration and runtime-permission checks.

## Event-plan handoff

Plan 02 now imports the G02 ownership matrix and SQL assertion seam in E0.10, and E8.10 requires a
symmetric callback after E2/E4. That callback must link the real entity mappings and module migrations,
run fresh/upgrade/rollback/duplicate/metadata checks, and update this document plus G02 Phase 10.

## Deferred owners, approvals and waivers

| Item | Owner | Due/expiry | Removal or acceptance condition |
| --- | --- | --- | --- |
| Real module-local Outbox entities and migrations | Plan 02 E2 | Before G02 final closure | Producer business data plus Outbox passes G01 atomicity and G02 SQL Server ownership/migration assertions |
| Real module-local Inbox entities and migrations | Plan 02 E4 | Before G02 final closure | `(ConsumerId, EventId)` uniqueness and consumer data plus completion pass G01/G02 conformance |
| Production Migrator → Worker → API sequencing | G04 / Release Operations | G04 Phase 8/10/12 before G02 final closure | Release-bound manifests, restore point, validation, consumer-first readiness and safe recovery evidence are linked |
| Final Gate approval | Architecture, Database and Operations owners | After the three evidence callbacks above | All reviewers sign the immutable closeout record |
| Stronger per-module production credentials | Database Operations / TODO DB5 | Future database hardening plan | Each module role and schema grant is implemented and tested without shared high privilege |
| Tenant lifecycle and orphan reconciliation | Architecture / TODO DB6–DB8 | Follow-up data lifecycle plan | Deactivate/delete, retention, tenant-aware access and reconciliation rules are approved and tested |
| Reporting and physical database split | Architecture + Data/Operations / TODO GOV3 and DB12 | Before either capability is introduced | Owned projections plus replication, backup/restore and migration strategy are approved |

There is no G02-specific waiver. G02-D26 is a scope decision, not permission to treat the controlled
Docker result as production evidence. No shared history deletion has been approved. Final approvals
are deliberately absent until the required callbacks exist.

## PRE-READY verification

- `dotnet build IFX.sln --no-restore`: passed with 0 errors and 15 existing warnings.
- `dotnet test IFX.sln --no-build --no-restore`: 904 passed, 0 failed.
- `IFX.DatabaseBoundary.Tests`: 93 passed, including three documentation/closeout checks.
- G02 Phase 10 guard: passed; 5 modules, 14 migrations, 0 schema violations and 0 secret findings.
- LayerGuard B0.5: `baseline-clean`; 116 matched, 0 new, 0 stale. Self-tests: 178 passed.

## Remaining closure conditions

- Plan 02 E2/E4 and E8.10 return real Outbox/Inbox database evidence.
- G04 returns production release orchestration evidence and closes G02-DD06.
- Architecture, Database and Operations owners approve Phase 10 after both callbacks are linked.
