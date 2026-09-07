# G02 Phase 3 — Auth squash and legacy adoption evidence

Date: 2026-09-07

## Result

Phase 3 is complete. Auth migration adoption now recognizes the real canonical InitialCreate,
the exact pre-squash catalog, and the former incorrect squash ID without treating unknown or
partial states as safe.

## Implemented controls

- The canonical Auth baseline is `20260327075710_InitialCreate`; its `ProductVersion` is read from
  the active migration assembly rather than hardcoded by the migration path.
- `AuthLegacyMigrationManifest` contains exactly 14 version-controlled pre-squash IDs. The former
  `20260317145706_InitialCreate` value is retained only as `IncorrectSquashAlias`.
- The deterministic inventory embeds the canonical baseline fingerprint: 22 tables, 155 columns,
  22 PK/unique keys, 23 foreign keys, and 38 indexes. It is generated from the canonical migration
  target model, not from a representative table.
- `SqlServerSchemaFingerprintReader` reads SQL Server tables, columns/types/nullability, PK and
  unique constraints, FKs, and indexes. `SchemaFingerprintComparer` requires an exact normalized
  match and reports missing, unexpected, or changed definitions.
- `AuthLegacyAdoptionPlanner` accepts only the exact 14-ID set, the single incorrect alias, or an
  explicitly approved historyless schema. Mixed, partial, unknown, or mismatched states return an
  invalid plan with no writes.
- `SqlServerAuthLegacyAdopter` obtains the database migration application lock, evaluates the full
  fingerprint, deletes any target-schema legacy rows, inserts the canonical row, rereads state,
  and validates it before committing one transaction. Legacy rows in shared `dbo` history remain
  read-only during the compatibility period.
- Long-running Auth, CRM, Registry, Holdings, and Transaction migrators no longer inspect one table
  and auto-stamp migration history. Auth's former automatic squash rewrite was also removed.
- Generic history bootstrap recognizes the versioned Auth legacy catalog but refuses to proceed
  until the Auth target history has been safely normalized.

## Verification

- `dotnet build IFX.sln --no-restore`: passed, 0 errors; 13 existing package/code warnings.
- `dotnet test IFX.sln --no-build --no-restore`: passed, 862 tests.
- `IFX.DatabaseBoundary.Tests`: passed, 51 tests, including correct-current, exact 14-ID source and
  target histories, wrong alias, partial legacy, fingerprint mismatch, explicit EnsureCreated
  adoption, canonical rerun, full fingerprint coverage, and bootstrap handoff.
- G02 deterministic inventory guard: passed; 5 modules, 14 current migrations, 0 schema ownership
  violations, and 0 secret findings.
- Static scan confirms the wrong alias and pre-squash IDs occur only in the dedicated legacy
  manifest, and no `StampIfEnsureCreatedDatabaseAsync` path remains under `src`.
- LayerGuard B0.5 comparison: `baseline-clean`; 116 matched, 0 new, 0 stale.

The SQL Server fixture execution of legacy adoption, transactional rollback, and rerun is retained
for the Phase 7 Testcontainers matrix; no production database action is claimed here.
