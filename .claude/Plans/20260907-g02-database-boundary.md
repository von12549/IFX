# G02 database-boundary implementation

Date: 2026-09-07

## Objective

Implement `docs/architecture/review/plans/00-G02-database-boundary.md` phase by phase. Keep the
current shared physical `IFXDb`, while making schema, connection, migration history, migration
execution, validation, and evidence explicitly module-owned.

## Sequence

1. Phase 0 — produce a reproducible, anonymized inventory of DbContexts, relational objects,
   migration catalogs/hashes, cross-schema risks, configuration surfaces, known database states,
   and migration risk classifications.
2. Phase 1 — add schema constants/default schemas, strict module connection configuration, model
   ownership tests, and static ownership guards.
3. Phase 2 — configure per-schema histories and implement fail-closed, dry-run history bootstrap.
4. Phase 3 — normalize Auth squash/legacy adoption with a full schema fingerprint and tests.
5. Phase 4 — build the one-shot `IFX.DatabaseMigrator`, generated manifest, modes, reports, and
   deterministic module execution.
6. Phase 5 — remove production DDL from ApiHost and add read-only compatibility/readiness plus
   deployment orchestration.
7. Phase 6 — codify Expand/Contract, partial-upgrade, recovery, and audit procedures.
8. Phase 7 — run the SQL Server migration matrix, including concurrency, permissions, legacy,
   failure injection, and E2/E4 reusable assertions.
9. Phase 8 — prepare environment rollout evidence; never claim production actions that were not
   actually performed.
10. Phase 9/10 — complete bilingual design/evidence and close only the conditions supported by
    real implementation and approvals.

## Progress

- Phase 0 complete: deterministic repository/model/migration baseline and guards.
- Phase 1 complete: module schema ownership and dedicated connection boundaries.
- Phase 2 complete: per-schema EF histories and transactional, fail-closed history bootstrap;
  live SQL Server behavior remains scheduled for the Phase 7 matrix.
- Phase 3 complete: Auth canonical/legacy normalization, full relational fingerprinting, and
  removal of single-table automatic stamping from long-running migrators.
- Phase 4 complete: one-shot DatabaseMigrator executable/image definition, versioned manifest,
  deterministic orchestration, explicit modes/exit codes, and structured module reports.
- Phase 5 complete: ApiHost production DDL removed, read-only release/schema compatibility added,
  version-matched SQL artifacts automated, and local/NAS deployment ordering enforced.
- Phase 6 complete: Expand/Contract review, destructive-migration policy enforcement, partial
  upgrade recovery, exceptional rollback and immutable upgrade audit controls established.
- Phase 7 complete: SQL Server 2022 migration matrix covers fresh/shared/legacy/historyless/partial,
  previous-release, concurrency, failure recovery and split migration/runtime permissions; CI now
  runs solution build, pending-model checks, SQL artifacts and the live matrix.

## Phase discipline

- Complete and verify one phase before modifying the next phase's implementation.
- Update the Gate plan only for evidence that exists.
- Generated inventory contains no secrets or business rows; environment-specific access and
  permission facts that are unavailable are recorded as explicit evidence gaps.
- Real Outbox/Inbox migrations remain owned by Plan 02 E2/E4 and are accepted back through the
  shared G01/G02 conformance seams.
- Run targeted tests while developing, then solution build/tests, G02 guard, and LayerGuard at
  each material boundary.

## Phase 0 deliverables

- A deterministic inventory generator that reads repository/model/migration metadata without a
  live production database.
- Machine-readable migration manifest with module, context, schema, history target, connection
  key, order, migration ID, product version, source file, and SHA-256 hash.
- Human-readable baseline covering relational assets, cross-schema/static scan findings,
  sanitized configuration/deployment identity surfaces, known database state fixtures, and DDL
  risk classification.
- Tests or guard checks that make missing modules, duplicate migration IDs, schema drift, secret
  leakage, and newly introduced static violations fail.

## Phase 0 acceptance

- All G02-0.1 through G02-0.7 have repository evidence or an explicitly scoped external evidence
  gap with owner and collection procedure.
- Inventory generation is deterministic and passes on the current tree.
- `dotnet build IFX.sln --no-restore`, relevant tests, G02 guard, and LayerGuard pass.
