namespace IFX.BuildingBlocks.EntityFrameworkCore.Migrations;

public enum ModuleSchemaState
{
    Absent,
    Complete,
    Partial
}

public enum HistoryBootstrapClassification
{
    Fresh,
    CurrentSharedHistory,
    AlreadyBootstrapped,
    ExplicitAdoptionRequired,
    Invalid
}

public sealed record MigrationHistoryRow(string MigrationId, string ProductVersion);

public sealed record ModuleMigrationCatalog(
    string Module,
    string Schema,
    int Order,
    IReadOnlyList<string> MigrationIds,
    IReadOnlyList<string> RequiredTables,
    IReadOnlyList<string>? LegacyMigrationIds = null);

public sealed record ModuleHistoryState(
    bool Exists,
    IReadOnlyList<MigrationHistoryRow> Rows);

public sealed record HistoryBootstrapSnapshot(
    bool SharedHistoryExists,
    IReadOnlyList<MigrationHistoryRow> SharedHistory,
    IReadOnlyDictionary<string, ModuleHistoryState> ModuleHistories,
    IReadOnlyDictionary<string, ModuleSchemaState> ModuleSchemas);

public sealed record ModuleHistoryBootstrapPlan(
    string Module,
    string Schema,
    bool CreateHistoryTable,
    IReadOnlyList<MigrationHistoryRow> RowsToInsert,
    IReadOnlyList<string> PendingMigrationIds);

public sealed record HistoryBootstrapPlan(
    HistoryBootstrapClassification Classification,
    IReadOnlyList<ModuleHistoryBootstrapPlan> Modules,
    IReadOnlyList<string> Errors)
{
    public bool CanApply => Errors.Count == 0;

    public bool HasChanges => Modules.Any(module =>
        module.CreateHistoryTable || module.RowsToInsert.Count > 0);
}

public sealed record HistoryBootstrapResult(
    bool DryRun,
    HistoryBootstrapPlan Before,
    HistoryBootstrapPlan? After);
