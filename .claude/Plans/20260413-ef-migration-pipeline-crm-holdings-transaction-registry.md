# Plan: EF Migration Pipeline — CRM, Holdings, Transaction, Registry

**Status:** Implemented — 2026-04-14

---

## Problem

Four modules use `Database.EnsureCreatedAsync()` in their `IAppMigrator` implementations.
`EnsureCreatedAsync` creates the schema on first run and **does nothing on subsequent runs**,
including when schema changes are deployed. This means:

- Any developer who ran the app before CRM V2 has a broken database — new tables and columns
  were never added. `EnsureCreatedAsync` detected existing tables and exited silently.
- CRM, Holdings, and Transaction each have EF migration files (generated for the V2 changes)
  that are **never applied** because the migrator bypasses the migration pipeline entirely.
- Registry has no migration files at all — it cannot track schema history.
- There is no `__EFMigrationsHistory` tracking for these modules, so there is no way to
  know what schema version any given environment is at.

Auth module already solved this with `Database.MigrateAsync()` + squashed baseline +
legacy-history stamping. This plan replicates that pattern for the remaining four modules.

---

## Goals

- Replace `EnsureCreatedAsync` with `MigrateAsync` in CRM, Holdings, Transaction, Registry
- Generate a squashed `InitialCreate` migration for each module representing the full current schema
- Write a migration stamping step for each migrator that handles existing databases (created via
  `EnsureCreatedAsync`) by inserting the `InitialCreate` row into `__EFMigrationsHistory` before
  `MigrateAsync` runs — preventing EF from trying to re-create tables that already exist
- Delete the now-superseded partial delta migration files (CRM V2, Holdings V2, Transaction V2)
  since the squashed baseline subsumes them
- Verify on both fresh databases (new dev setup) and existing databases (stamping path)

## Non-Goals

- Changing connection string topology (modules may share one SQL Server DB or use separate ones
  — this plan works either way since `__EFMigrationsHistory` is per-connection-string)
- Adding seed data to any module (separate concern — Auth seed lives in `InitialSeed` migration)
- Modifying the `IAppMigrator` interface or the ApiHost discovery loop

---

## Architecture

### The Auth Pattern (reference implementation)

`AuthMigrator.MigrateAsync()` does three things in order:

1. **Legacy detection** — checks `GetAppliedMigrationsAsync()` for old pre-squash IDs;
   if found, deletes them and inserts the squashed `InitialCreate` ID
2. **Pending migration logging** — calls `GetPendingMigrationsAsync()` and logs count
3. **Apply** — calls `Database.MigrateAsync()`

For modules being migrated off `EnsureCreatedAsync`, step 1 is different:
instead of replacing old IDs, we detect *absence* of any history for a module whose
tables already exist (the `EnsureCreatedAsync` signature) and stamp the `InitialCreate`.

### Stamping Logic (EnsureCreatedAsync → MigrateAsync transition)

```csharp
private async Task StampIfEnsureCreatedDatabaseAsync(DbContext db, string initCreateId,
    string probeTable, string probeSchema, CancellationToken ct)
{
    // If __EFMigrationsHistory already has our InitialCreate, nothing to do
    var applied = (await db.Database.GetAppliedMigrationsAsync(ct)).ToHashSet();
    if (applied.Contains(initCreateId)) return;

    // Check if the module's tables exist (created by EnsureCreatedAsync previously)
    var tableExists = await db.Database
        .SqlQueryRaw<int>($"""
            SELECT COUNT(*) FROM INFORMATION_SCHEMA.TABLES
            WHERE TABLE_SCHEMA = '{probeSchema}' AND TABLE_NAME = '{probeTable}'
            """)
        .FirstOrDefaultAsync(ct) > 0;

    if (!tableExists) return; // Fresh database — let MigrateAsync create everything

    // Tables exist but no history row — stamp InitialCreate as already applied
    Log.Warning("[{Module}] Detected EnsureCreatedAsync database. Stamping '{Id}'...", Name, initCreateId);
    await db.Database.ExecuteSqlRawAsync(
        "INSERT INTO [__EFMigrationsHistory] ([MigrationId], [ProductVersion]) VALUES ({0}, {1})",
        [initCreateId, "8.0.0"], ct);
    Log.Information("[{Module}] Stamp complete.", Name);
}
```

---

## Migration IDs (stable — hardcoded in migrators)

| Module      | New InitialCreate ID                    | Replaces                                        |
|-------------|----------------------------------------|-------------------------------------------------|
| CRM         | `20260413120000_InitialCreate`         | `20260413095800_CrmV2_InvestmentAccount_PartyRelationships` |
| Holdings    | `20260413120100_InitialCreate`         | `20260413095819_HoldingsV2_InvestmentAccountId` |
| Transaction | `20260413120200_InitialCreate`         | `20260413095944_TransactionV2_InvestmentAccountId` |
| Registry    | `20260413120300_InitialCreate`         | *(none — no migrations existed)*               |

---

## Implementation Steps

### Phase 1 — CRM

**Context:** `CrmDbContext` in `IFX.Modules.CRM.Infrastructure`
**Migrator:** `CrmMigrator` in `IFX.Modules.CRM.Infrastructure/Persistence/CrmMigrator.cs`
**Probe:** schema=`crm`, table=`Parties`

- [x] Delete `20260413095800_CrmV2_InvestmentAccount_PartyRelationships.cs` and `.Designer.cs`
- [x] Generate squashed `InitialCreate` migration:
  ```bash
  cd src/Modules/CRM/IFX.Modules.CRM.Infrastructure
  dotnet ef migrations add InitialCreate \
    --startup-project ../../../ApiHost/IFX.ApiHost \
    --output-dir Migrations
  ```
  Rename the generated file timestamps to `20260413120000` in both the `.cs` and `.Designer.cs`
  filenames and in the `[Migration("...")]` attribute inside the `.Designer.cs`
- [x] Update `CrmDbContextModelSnapshot.cs` — regenerated automatically by the `add` command
- [x] Replace `CrmMigrator.MigrateAsync` body:
  ```csharp
  public string Name => "CRM";
  private const string InitialCreateId = "20260413120000_InitialCreate";
  private const string EfProductVersion = "8.0.0";

  public async Task MigrateAsync(IServiceProvider sp, CancellationToken ct = default)
  {
      Log.Information("[{Module}] Starting database migration...", Name);
      var db = sp.GetRequiredService<CrmDbContext>();
      await StampIfEnsureCreatedDatabaseAsync(db, ct);
      var pending = await db.Database.GetPendingMigrationsAsync(ct);
      var count = pending.Count();
      if (count > 0)
          Log.Information("[{Module}] Applying {Count} pending migration(s)...", Name, count);
      else
          Log.Information("[{Module}] No pending migrations.", Name);
      await db.Database.MigrateAsync(ct);
      Log.Information("[{Module}] Migration completed.", Name);
  }

  private async Task StampIfEnsureCreatedDatabaseAsync(CrmDbContext db, CancellationToken ct)
  {
      var applied = (await db.Database.GetAppliedMigrationsAsync(ct)).ToHashSet();
      if (applied.Contains(InitialCreateId)) return;
      var exists = (await db.Database.SqlQueryRaw<int>(
          "SELECT COUNT(*) FROM INFORMATION_SCHEMA.TABLES " +
          "WHERE TABLE_SCHEMA = 'crm' AND TABLE_NAME = 'Parties'").ToListAsync(ct)).FirstOrDefault() > 0;
      if (!exists) return;
      Log.Warning("[{Module}] Detected EnsureCreatedAsync database. Stamping '{Id}'...", Name, InitialCreateId);
      await db.Database.ExecuteSqlRawAsync(
          "INSERT INTO [__EFMigrationsHistory] ([MigrationId], [ProductVersion]) VALUES ({0}, {1})",
          [InitialCreateId, EfProductVersion], ct);
  }
  ```
- [x] Add `using Serilog;` and `using Microsoft.EntityFrameworkCore;` to `CrmMigrator.cs`

### Phase 2 — Holdings

**Context:** `HoldingsDbContext` in `IFX.Modules.Holdings.Infrastructure`
**Migrator:** `HoldingsMigrator` in `IFX.Modules.Holdings.Infrastructure/Persistence/HoldingsMigrator.cs`
**Probe:** schema=`holdings`, table=`Holdings`

- [x] Delete `20260413095819_HoldingsV2_InvestmentAccountId.cs` and `.Designer.cs`
- [x] Generate squashed `InitialCreate` migration:
  ```bash
  cd src/Modules/Holdings/IFX.Modules.Holdings.Infrastructure
  dotnet ef migrations add InitialCreate \
    --startup-project ../../../ApiHost/IFX.ApiHost \
    --output-dir Migrations
  ```
  Rename timestamps to `20260413120100`
- [x] Replace `HoldingsMigrator.MigrateAsync` with stamping + `MigrateAsync` pattern
  (same structure as CRM; probe: schema=`holdings`, table=`Holdings`; ID=`20260413120100_InitialCreate`)

### Phase 3 — Transaction

**Context:** `TransactionDbContext` in `IFX.Modules.Transaction.Infrastructure`
**Migrator:** `TransactionMigrator` in `IFX.Modules.Transaction.Infrastructure/Persistence/TransactionMigrator.cs`
**Probe:** schema=`transaction`, table=`Transactions`

- [x] Delete `20260413095944_TransactionV2_InvestmentAccountId.cs` and `.Designer.cs`
- [x] Generate squashed `InitialCreate` migration:
  ```bash
  cd src/Modules/Transaction/IFX.Modules.Transaction.Infrastructure
  dotnet ef migrations add InitialCreate \
    --startup-project ../../../ApiHost/IFX.ApiHost \
    --output-dir Migrations
  ```
  Rename timestamps to `20260413120200`
- [x] Replace `TransactionMigrator.MigrateAsync` with stamping + `MigrateAsync` pattern
  (probe: schema=`transaction`, table=`Transactions`; ID=`20260413120200_InitialCreate`)

### Phase 4 — Registry

**Context:** `RegistryDbContext` in `IFX.Modules.Registry.Infrastructure`
**Migrator:** `RegistryMigrator` in `IFX.Modules.Registry.Composition/RegistryMigrator.cs`
**Probe:** schema=`registry`, table=`Funds`

- [x] Confirm Registry Infrastructure has a `Migrations/` folder — create it if absent
- [x] Generate squashed `InitialCreate` migration:
  ```bash
  cd src/Modules/Registry/IFX.Modules.Registry.Infrastructure
  dotnet ef migrations add InitialCreate \
    --startup-project ../../../ApiHost/IFX.ApiHost \
    --output-dir Migrations
  ```
  Rename timestamps to `20260413120300`
- [x] Replace `RegistryMigrator.MigrateAsync` with stamping + `MigrateAsync` pattern
  (probe: schema=`registry`, table=`Funds`; ID=`20260413120300_InitialCreate`)
- [x] Move `RegistryMigrator.cs` from `Registry.Composition` to
  `Registry.Infrastructure/Persistence/` to match the pattern of other modules
  (update the `IAppMigrator` registration in `RegistryModuleInstaller.cs` accordingly)

### Phase 5 — Verify correct schema probe names

- [x] Confirm actual SQL schema names used by each module (check EF configurations):
  - CRM: `ToTable("Parties", "crm")` → probe schema=`crm`
  - Holdings: confirm schema name used in `HoldingConfiguration`
  - Transaction: confirm schema name used in `TransactionConfiguration`
  - Registry: confirm schema name used in `FundConfiguration`
- [x] Adjust probe table/schema constants in each migrator if different from the defaults above

### Phase 6 — Test

- [x] **Fresh database test:** Drop all module databases, restart app — verify all four modules
  run `MigrateAsync`, create `__EFMigrationsHistory` entries, and all tables are created
- [x] **Existing database test:** Start with databases that were created by `EnsureCreatedAsync`
  (no `__EFMigrationsHistory` rows for these modules) — verify stamping logic fires, logs
  the warning, inserts the history row, and `MigrateAsync` finds zero pending migrations
- [x] **Already-migrated test:** Run the app twice — second run should log "No pending migrations"
  for all four modules with no errors
- [x] `dotnet test IFX.sln` — all 690 tests still pass

---

## Risks and Mitigations

| Risk | Mitigation |
|------|-----------|
| Generated `InitialCreate` migration missing tables if model snapshot is stale | Run `dotnet ef migrations add` after a clean build; review the generated `.cs` to confirm all expected tables are present |
| Probe table or schema name wrong → stamping skips, `MigrateAsync` tries to create tables that exist → SQL error | Verify schema names from EF configs before implementing (Phase 5); test on existing DB before merging |
| CRM's existing `20260413095800` migration references a specific EF model state that the new `InitialCreate` must match | Delete the old migration file *before* running `add InitialCreate` so EF generates from the clean current snapshot |
| `__EFMigrationsHistory` shared across modules (same SQL Server database) | Not a problem — each module's migration IDs are unique; EF only applies rows with matching IDs per `MigrationsAssembly` |
| Registry migrator currently lives in `Registry.Composition` (different from all others) | Phase 4 moves it to `Registry.Infrastructure/Persistence/` for consistency |

---

## File Inventory

### Deleted
- `src/Modules/CRM/IFX.Modules.CRM.Infrastructure/Migrations/20260413095800_CrmV2_InvestmentAccount_PartyRelationships.cs`
- `src/Modules/CRM/IFX.Modules.CRM.Infrastructure/Migrations/20260413095800_CrmV2_InvestmentAccount_PartyRelationships.Designer.cs`
- `src/Modules/Holdings/IFX.Modules.Holdings.Infrastructure/Migrations/20260413095819_HoldingsV2_InvestmentAccountId.cs`
- `src/Modules/Holdings/IFX.Modules.Holdings.Infrastructure/Migrations/20260413095819_HoldingsV2_InvestmentAccountId.Designer.cs`
- `src/Modules/Transaction/IFX.Modules.Transaction.Infrastructure/Migrations/20260413095944_TransactionV2_InvestmentAccountId.cs`
- `src/Modules/Transaction/IFX.Modules.Transaction.Infrastructure/Migrations/20260413095944_TransactionV2_InvestmentAccountId.Designer.cs`

### Created
- `src/Modules/CRM/IFX.Modules.CRM.Infrastructure/Migrations/20260413120000_InitialCreate.cs`
- `src/Modules/CRM/IFX.Modules.CRM.Infrastructure/Migrations/20260413120000_InitialCreate.Designer.cs`
- `src/Modules/Holdings/IFX.Modules.Holdings.Infrastructure/Migrations/20260413120100_InitialCreate.cs`
- `src/Modules/Holdings/IFX.Modules.Holdings.Infrastructure/Migrations/20260413120100_InitialCreate.Designer.cs`
- `src/Modules/Transaction/IFX.Modules.Transaction.Infrastructure/Migrations/20260413120200_InitialCreate.cs`
- `src/Modules/Transaction/IFX.Modules.Transaction.Infrastructure/Migrations/20260413120200_InitialCreate.Designer.cs`
- `src/Modules/Registry/IFX.Modules.Registry.Infrastructure/Migrations/20260413120300_InitialCreate.cs`
- `src/Modules/Registry/IFX.Modules.Registry.Infrastructure/Migrations/20260413120300_InitialCreate.Designer.cs`
- `src/Modules/Registry/IFX.Modules.Registry.Infrastructure/Persistence/RegistryMigrator.cs` *(moved from Composition)*

### Modified
- `src/Modules/CRM/IFX.Modules.CRM.Infrastructure/Migrations/CrmDbContextModelSnapshot.cs` *(regenerated)*
- `src/Modules/CRM/IFX.Modules.CRM.Infrastructure/Persistence/CrmMigrator.cs`
- `src/Modules/Holdings/IFX.Modules.Holdings.Infrastructure/Migrations/HoldingsDbContextModelSnapshot.cs` *(regenerated)*
- `src/Modules/Holdings/IFX.Modules.Holdings.Infrastructure/Persistence/HoldingsMigrator.cs`
- `src/Modules/Transaction/IFX.Modules.Transaction.Infrastructure/Migrations/TransactionDbContextModelSnapshot.cs` *(regenerated)*
- `src/Modules/Transaction/IFX.Modules.Transaction.Infrastructure/Persistence/TransactionMigrator.cs`
- `src/Modules/Registry/IFX.Modules.Registry.Composition/RegistryModuleInstaller.cs` *(update migrator registration namespace)*

---

## Reference: Auth Module Files

The Auth pattern to replicate:
- Migrator: `src/Modules/Auth/IFX.Modules.Auth.Composition/EFMigrator.cs`
- DbContext: `src/Modules/Auth/IFX.Modules.Auth.Infrastructure/Persistence/IfxDbContext.cs`
- Migrations: `src/Modules/Auth/IFX.Modules.Auth.Infrastructure/Persistence/Migrations/`
