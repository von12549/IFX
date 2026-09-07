# G02 Phase 4 — DatabaseMigrator and module manifest evidence

Date: 2026-09-07

## Result

Phase 4 is complete. `IFX.DatabaseMigrator` is an independent one-shot executable with a
publishable runtime image, a version-controlled module manifest, deterministic execution, four
explicit operating modes, fail-closed validation, and structured machine-readable results.

## Implemented controls

- The executable references only the shared EF migration building block and the five module
  Infrastructure projects. It does not use the ASP.NET SDK, Composition projects, HTTP hosting,
  background jobs, or message consumers.
- `migration-manifest.json` records ModuleName, fully qualified DbContext, schema, history table,
  connection key, stable order, dependencies, and the exact assembly-backed migration catalog with
  ProductVersion and source SHA-256.
- Startup validation rejects unsupported formats, missing or unexpected modules, duplicate module
  metadata/order/MigrationId, missing dependencies, dependency cycles, invalid hashes, absent
  contexts, and any manifest/assembly mismatch before database writes.
- Execution order is fixed as history preflight/bootstrap, Auth legacy normalization when required,
  Auth, CRM, Registry, Holdings, Transaction, then post-validation. A session-owned SQL Server
  application lock covers the complete apply operation; module migrations remain separate
  roll-forward units.
- `preflight`, `dry-run`, `apply`, and `validate` are explicit CLI modes. Exit codes distinguish
  configuration (2), preflight (10), lock (20), module migration (30), and validation (40) failures
  from success (0).
- The JSON report records mode, timestamps, result/failure point, bootstrap/adoption plans, and per
  module before/after version, pending/applied IDs, duration, and result. SQL exceptions are reduced
  to an error number so connection secrets are not emitted.
- The PowerShell launcher provides an explicit local/operator command. The Dockerfile builds a
  one-shot runtime image whose default command is `apply`; the Release publish output includes the
  executable and manifest.
- The coordinator contains no module table definitions. All schema DDL and migrations continue to
  be owned by the corresponding module Infrastructure assembly.

## Verification

- `dotnet publish` for `IFX.DatabaseMigrator` in Release mode: passed; publish output contained the
  executable and `migration-manifest.json`.
- Missing required connection configuration failed fast with exit code 2 and did not print a
  connection value.
- `dotnet build IFX.sln --no-restore`: passed, 0 errors; 14 existing package warnings.
- `dotnet test IFX.sln --no-build --no-restore`: passed, 873 tests.
- `IFX.DatabaseBoundary.Tests`: passed, 62 tests, including manifest/assembly equivalence, missing
  module, duplicate order, dependency cycle, stable runtime order, all CLI modes, and prohibited
  host dependency checks.
- G02 deterministic guard: passed; 5 modules, 46 entities, 40 tables, 14 migrations, 0 cross-schema
  findings, and 0 secret findings.
- LayerGuard B0.5 comparison: `baseline-clean`; 116 matched, 0 new, 0 stale. The special-purpose
  DatabaseMigrator is outside the existing application ring classifier and is therefore covered by
  the dedicated project-reference and manifest tests above.

No production database was modified. Live SQL execution remains an explicit Phase 7 requirement.
