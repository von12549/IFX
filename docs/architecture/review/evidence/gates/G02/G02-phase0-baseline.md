# G02 Phase 0 database baseline

> Scope: repository source, compiled EF Core models, migrations, checked-in configuration, and
> Compose definitions at commit `80053bd` plus the uncommitted G02 Phase 0 implementation.
> This evidence does not claim access to a deployed test or production database.

## Reproduction

```powershell
dotnet build tools/IFX.DatabaseInventory/IFX.DatabaseInventory.csproj --no-restore
./scripts/Invoke-G02DatabaseBoundaryGuard.ps1 -NoBuild
```

The guard generates these machine-readable artifacts:

- `G02-database-inventory.json`: complete compiled-model inventory, configuration surfaces,
  static scan, known-state taxonomy, and external evidence ownership.
- `G02-migration-manifest.json`: ordered module migration catalog with ProductVersion and source
  SHA-256.
- `G02-phase0-guard-report.json`: reproducibility, ownership, catalog, and secret-leak checks.

The generator uses a non-connected design-time SQL Server configuration. It reads EF metadata and
repository files only; it does not connect to any database or export application rows.

## Relational ownership inventory

| Module | Schema | DbContext | Migration assembly | Entity types | Unique tables | Indexes | FKs | Columns | Migrations |
| --- | --- | --- | --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Auth | `auth` | `IfxDbContext` | `IFX.Modules.Auth.Infrastructure` | 23 | 22 | 38 | 23 | 156 | 4 |
| CRM | `crm` | `CrmDbContext` | `IFX.Modules.CRM.Infrastructure` | 12 | 12 | 23 | 12 | 154 | 2 |
| Registry | `registry` | `RegistryDbContext` | `IFX.Modules.Registry.Infrastructure` | 3 | 3 | 5 | 1 | 46 | 3 |
| Holdings | `holdings` | `HoldingsDbContext` | `IFX.Modules.Holdings.Infrastructure` | 1 | 1 | 3 | 0 | 11 | 2 |
| Transaction | `transaction` | `TransactionDbContext` | `IFX.Modules.Transaction.Infrastructure` | 7 | 2 | 7 | 6 | 63 | 3 |
| **Total** |  |  |  | **46** | **40** | **76** | **42** | **430** | **14** |

Owned types that share a table are counted as EF entity types but not as additional tables. The
machine-readable inventory records each primary key, index, foreign key, column mapping, and
sequence. It also records all 46 relational keys and confirms the current model has no check
constraints. All current relational objects and FK principals resolve to their owning module schema;
the Phase 0 guard reports zero schema violations.

## Migration and history baseline

The current five DbContexts all use the shared `dbo.__EFMigrationsHistory`. The approved target is
one `__EFMigrationsHistory` table in each module schema. The manifest order is Auth (10), CRM (20),
Registry (30), Holdings (40), Transaction (50). It contains 14 unique migration IDs and records
the source SHA-256 for drift detection. The migration target models currently report EF Core
ProductVersion `8.0.0`.

Auth contains four current migrations. Its canonical InitialCreate is
`20260327075710_InitialCreate`; the repository also contains a recognized 14-ID pre-squash history
and the incorrect `20260317145706_InitialCreate` alias in legacy adoption code. These are inventory
facts only—normalization is implemented in Phase 3.

## Static boundary scan

- Cross-schema model/migration findings: **0**.
- `CREATE VIEW`, `CREATE TRIGGER`, and `CREATE PROCEDURE` definitions: **0**.
- Raw SQL call sites: **51**. These are Auth seed/legacy-adoption SQL plus the representative-table
  adoption logic in CRM, Registry, Holdings, and Transaction. Every finding and source line is in
  the inventory; Phase 3 removes the unsafe long-running adoption path.
- All **52** schema-qualified table references are recorded separately. Direct table access outside the
  owning module detected by the current scan: **0**.

The scan is deterministic and fails immediately on a cross-schema migration reference or compiled
model/FK ownership violation. It is a repository guard, not a substitute for the SQL Server
metadata checks added in Phase 7.

## Configuration, identity, and permission surfaces

Five module keys are required: `AuthDatabase`, `CrmDatabase`, `RegistryDatabase`,
`HoldingsDatabase`, and `TransactionDatabase`.

- `docker-compose.yml` declares all five and currently points them to `IFXDb` using the same
  environment-provided database credential.
- `docker-compose.nas.yml` declares only `AuthDatabase`; the other four module keys are absent.
- checked-in ApiHost settings declare only Auth and BackgroundJobs (blank in base settings and
  test-only values in Testing settings).
- CRM, Registry, Holdings, and Transaction each fall back to `DefaultConnection`.
- migration and runtime identities are not separated: startup migration currently uses the same
  credential as the runtime host.

No connection string, login, password, token, or business row is included in this evidence.
Environment-specific server/database identities and effective DDL/DML grants are an external
evidence gap owned by **Database Operations**. Before Phase 5 rollout, the owner must map every
module key in each environment to a sanitized server/database identifier and identity role, then
capture effective grants showing migration identity DDL capability and runtime identity restricted
to required DML/readiness. Values of secrets must never be exported.

## Known database states

| State | Repository signal | Classification | Required behavior |
| --- | --- | --- | --- |
| Fresh | no module tables or history | safe | apply canonical module migrations |
| Current shared | known IDs in `dbo.__EFMigrationsHistory` | bootstrap required | copy exact owned IDs; retain shared history read-only |
| EnsureCreated | full schema fingerprint, no history | explicit adoption only | adopt only on a complete fingerprint match |
| Auth pre-squash | exact known 14-ID catalog | known legacy | transactionally normalize to canonical InitialCreate |
| Wrong Auth squash | `20260317145706_InitialCreate` | known legacy alias | normalize to the canonical ID |
| Unknown/partial | unknown ID or incomplete fingerprint | fail closed | do not stamp or migrate automatically |

These are sanitized repository fixtures, not observations of a deployed database. A metadata-only
test sample will be captured by Phase 7. Production schema/history remains an external evidence gap
owned by **Database Operations**: export only `sys.schemas`, `sys.tables`, `sys.columns`,
`sys.indexes`, `sys.foreign_keys`, and migration-history metadata; redact server/login identifiers;
exclude all business tables and data; review the output for secrets before committing it.

## Migration risk classification

| Risk | Count | Signal | Required treatment |
| --- | ---: | --- | --- |
| High | 5 | `AlterColumn` audit timestamp conversions, with conversion and table-lock risk | backup/restore point, reviewed SQL, compatibility and duration testing |
| Medium | 9 | index creation or data-changing seed/backfill SQL | review lock/data impact and rehearse against representative volume |
| Low | 0 | no current migration classified as metadata-only | none at baseline |

The classifier examines each migration's `Up` method. It is deliberately conservative and does
not prove production duration, reversibility, or data safety. Phase 6 adds release policy and
Phase 7 measures behavior on SQL Server.

## Phase 0 external evidence register

| Evidence | Status | Owner | Collection gate |
| --- | --- | --- | --- |
| Repository EF/schema/migration inventory | complete | Engineering | Phase 0 guard |
| Checked-in configuration and Compose inventory | complete | Engineering | Phase 0 guard |
| Environment database identities and effective DDL/DML grants | external gap | Database Operations | required before Phase 5 rollout |
| Test SQL Server metadata/history sample | deferred implementation evidence | Engineering | Phase 7 migration matrix |
| Production metadata/history sample | external gap | Database Operations | required before Phase 8 production dry-run |

Phase 0 accepts these explicitly scoped external gaps; it does not treat them as evidence that a
real environment is compliant.

## Verification result

- G02 Phase 0 guard: passed; both generated artifacts reproduced byte-for-byte, with inventory
  SHA-256 `ed4f300321e3acdb4a41c75066de2dd6ff82c2f056e3d1c4d6efc3de4648d4de` and manifest
  SHA-256 `59ddebdc56462fc5de083ed4e522f5adb07eb373fc4263a2d8f3b6e806377cdb`.
- Solution build: passed with 0 errors; 13 existing package/obsolete API warnings remain.
- Solution tests: 811 passed, 0 failed, 0 skipped.
- LayerGuard B0.5 comparison: `baseline-clean`; 116 matched, 0 new, 0 stale.
