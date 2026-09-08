# G02 Module database boundary

> Status: G02 phases 0–9 and the Plan 02/B3 real Outbox/Inbox repository handback are implemented; final closure awaits G04 production orchestration evidence and Phase 10 approval.
> Chinese version: [database-boundary.zh-CN.md](database-boundary.zh-CN.md)
> Decision record: [ADR-G02-001](ADR-G02-001-module-database-ownership.md)

## 1. Boundary model

IFX keeps one SQL Server and one physical `IFXDb` for now, but it has five logical database
boundaries. Each module owns its DbContext, schema, connection key, migration assembly and
schema-local history table. The same server is a deployment optimization, not permission to share
tables or transactions.

| Module | DbContext | Schema | Connection key | Migration history |
| --- | --- | --- | --- | --- |
| Auth | `IfxDbContext` | `auth` | `AuthDatabase` | `auth.__EFMigrationsHistory` |
| CRM | `CrmDbContext` | `crm` | `CrmDatabase` | `crm.__EFMigrationsHistory` |
| Registry | `RegistryDbContext` | `registry` | `RegistryDatabase` | `registry.__EFMigrationsHistory` |
| Holdings | `HoldingsDbContext` | `holdings` | `HoldingsDatabase` | `holdings.__EFMigrationsHistory` |
| Transaction | `TransactionDbContext` | `transaction` | `TransactionDatabase` | `transaction.__EFMigrationsHistory` |

A module may not use another module's DbContext or directly read/write its tables. Cross-schema
foreign keys, EF navigations, joins, triggers and stored procedures are prohibited. Synchronous
access uses a Contract through a consumer-owned Port/Adapter; asynchronous propagation uses a durable
Event. Outbox/Inbox tables follow the owning module DbContext and schema—there is no shared messaging
DbContext. Plan 02 E2/E4 supplies the real tables and final relational evidence.

See the [database architecture source](diagrams/database-architecture.mmd) and
[rendered SVG](diagrams/database-architecture.svg).

## 2. Decisions and physical split seam

| Decisions | Rule |
| --- | --- |
| G02-D01–D07 | Shared physical database, strict schema ownership, default schemas, dedicated connection keys and schema-local history/Outbox/Inbox. |
| G02-D08–D15 | Explicit fail-closed history bootstrap, full fingerprints, exact ownership mapping, transactional normalization, dry-run, restore point and read-only legacy history. |
| G02-D16–D20 | One-shot Migrator, deterministic manifest order, database application lock, stop on first failure and roll forward. |
| G02-D21–D25 | Expand/Contract, split migration/runtime identities, deterministic Compose order, real SQL Server matrix and read-only readiness. |
| G02-D26 | The approved isolated Docker rehearsal closes implementation validation only; production execution is re-approved and captured by G04/Release Operations. |

Every module connection key may currently resolve to `IFXDb`. For a future split, operations changes
one module's connection target and migrates that module's owned schema; Application and Domain do not
change. Before a split, Contracts/Events must replace any remaining physical co-location assumption,
and reporting/backup/recovery is designed explicitly.

## 3. History bootstrap

Bootstrap classifies before writing:

- `fresh`: no owned schema/history; run normal pending migrations;
- `current shared`: every recognized shared history row maps exactly to one module, then is copied
  with its original ProductVersion;
- `known legacy`: only a complete schema fingerprint permits canonical adoption, including the Auth
  pre-squash IDs and the erroneous squash alias;
- `current module`: schema-local histories already agree with the manifest;
- `unknown`, mixed, partial or fingerprint mismatch: fail closed without automatic stamping.

The database-level application lock covers bootstrap and the full upgrade. Bootstrap normalization is
transactional; module migrations are not wrapped in one global transaction. Repeating a successful
run produces no changes. The old `dbo.__EFMigrationsHistory`, when present, is retained read-only for
the first compatibility window; deletion requires a separate approval.

See the [bootstrap state source](diagrams/history-bootstrap.mmd) and
[rendered SVG](diagrams/history-bootstrap.svg).

## 4. Migrator manifest and commands

The versioned manifest has this shape:

```json
{
  "formatVersion": 1,
  "physicalDatabase": "IFXDb",
  "modules": [{
    "moduleName": "Auth",
    "dbContext": "fully.qualified.DbContext",
    "schema": "auth",
    "historyTable": "__EFMigrationsHistory",
    "connectionKey": "AuthDatabase",
    "order": 10,
    "dependsOn": [],
    "migrations": [{ "migrationId": "...", "productVersion": "8.0.0", "sourceSha256": "..." }]
  }]
}
```

Use the same immutable artifact and five module connection settings for every mode:

```powershell
./scripts/Invoke-DatabaseMigrator.ps1 -Mode preflight -ReportPath artifacts/preflight.json
./scripts/Invoke-DatabaseMigrator.ps1 -Mode dry-run  -ReportPath artifacts/dry-run.json
./scripts/Invoke-DatabaseMigrator.ps1 -Mode apply    -ReportPath artifacts/apply.json
./scripts/Invoke-DatabaseMigrator.ps1 -Mode validate -ReportPath artifacts/validate.json
./scripts/New-DatabaseMigrationArtifacts.ps1 -OutputDirectory artifacts/database-migrator
```

A dry-run report records `Mode`, timestamps, `Result`, `FailurePoint`, errors and the bootstrap plan.
Each module includes schema, whether a history table is created, rows to insert and pending migration
IDs; `CanApply` must be true before approval. Exit codes are `0` success, `2` configuration, `10`
preflight, `20` lock, `30` module migration and `40` validation failure.

## 5. Production deployment and recovery

Freeze the immutable API/Worker/Migrator images, release/migration/artifact manifests and reviewed SQL.
After architecture, database and operations approval: preflight and dry-run; verify a backup or restore
point; acquire the lock; bootstrap if required; apply Auth → CRM → Registry → Holdings → Transaction;
validate; deploy compatible Worker consumers before API producers; then observe readiness, smoke tests
and the compatibility window. ApiHost starts only after validation and checks `/health/database`
without DDL. Aggregate `/health/ready` may still reflect external dependencies.

See the [production flow source](diagrams/production-migration-flow.mmd) /
[SVG](diagrams/production-migration-flow.svg), [failure recovery source](diagrams/failure-recovery.mmd) /
[SVG](diagrams/failure-recovery.svg), and [Expand/Contract source](diagrams/expand-contract.mmd) /
[SVG](diagrams/expand-contract.svg).

On lock timeout, unknown commit outcome, module failure or failed validation: stop the new release,
preserve reports and histories, classify from a new connection, repair and rerun the same reviewed
artifact. Later modules do not run after the first failure. Never automatically run EF `Down`.
Restore/database rollback is exceptional: it needs a verified restore point, rehearsed script, stated
data loss and architecture/database/operations approval. An older image may return only when its
release manifest declares the current schema compatible.

## 6. Common failures and forbidden modes

| Signal | Meaning and response |
| --- | --- |
| Unknown/duplicate migration ownership | Manifest or database is unsafe; correct the artifact/state, do not stamp. |
| Partial schema/fingerprint mismatch | Preserve state and investigate; automatic legacy adoption is forbidden. |
| Application-lock timeout | Identify the active owner; do not kill an unknown session just to proceed. |
| Module migration failure | Freeze API/Worker rollout, diagnose, then roll forward from the recorded partial state. |
| Validation/readiness failure | Keep the new application blocked even if migrations returned successfully. |
| Advanced incompatible schema | Do not roll back to that application image. |

Forbidden modes are runtime/API migration, `EnsureCreated` for a persistent environment, hand-edited
history rows, automatic `Down`, cross-schema DDL/access, a shared messaging DbContext, unreviewed
destructive SQL, secrets/business rows in evidence, and treating an image rollback as database
rollback.

The operational details are in the [rollout runbook](../../evidence/gates/G02/G02-phase8-rollout-runbook.md)
and [failure runbook](../../evidence/gates/G02/G02-phase6-recovery-runbook.md).

## 7. Rule-to-evidence map

| Rule | Enforcement/evidence |
| --- | --- |
| Module default schema and every relational object stays owned | `ModuleSchemaOwnershipTests`, `SqlServerMigrationMatrixTests`, G02 guard |
| Dedicated connection key and physical split seam | `ModuleConnectionConfigurationTests`, configuration startup validation |
| Schema-local history and exact bootstrap mapping | `HistoryBootstrap*Tests`, live SQL Server shared/legacy matrix |
| Auth canonical/legacy adoption uses a full fingerprint | `AuthLegacyAdoption*Tests`, partial-state failure matrix |
| Manifest integrity and deterministic order | `DatabaseMigratorManifestTests`, artifact generation CI check |
| Lock, failure stop, rerun and validation | SQL Server concurrency/failure matrix and structured reports |
| Runtime cannot perform DDL; API migration path absent | Phase 8 permission report, `SchemaCompatibilityTests`, static G02 guard |
| Required schema is read-only readiness | `/health/database`, `SchemaCompatibilityHealthCheckTests` |
| Destructive/Contract change requires review | migration safety policy and architecture/database/operations approval |
| Cross-module compile/data access stays forbidden | LayerGuard B0.5, database metadata assertions, manual SQL review |
| Real module Outbox/Inbox ownership and atomicity | Returned by Plan 02 E2/E4 at B3; production orchestration/final approval open |

Evidence starts at the [G02 evidence directory](../../evidence/gates/G02/) and the controlled rehearsal
is recorded in [rollout-evidence.json](../../evidence/gates/G02/phase8-docker-rehearsal/rollout-evidence.json).
