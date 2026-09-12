using IFX.BuildingBlocks.EntityFrameworkCore.Migrations;
using IFX.Modules.IAM.Infrastructure.Persistence.Migrations.Legacy;

namespace IFX.DatabaseMigrator;

public sealed record MigratorReport(
    string Mode,
    DateTimeOffset StartedAt,
    DateTimeOffset FinishedAt,
    string Result,
    string? FailurePoint,
    IReadOnlyList<string> Errors,
    HistoryBootstrapPlan? HistoryBootstrap,
    AuthLegacyAdoptionPlan? AuthLegacyAdoption,
    IReadOnlyList<ModuleMigrationReport> Modules);

public sealed record ModuleMigrationReport(
    string Module,
    string Schema,
    string HistoryTable,
    string? BeforeVersion,
    string? AfterVersion,
    IReadOnlyList<string> PendingBefore,
    IReadOnlyList<string> AppliedIds,
    long DurationMilliseconds,
    string Result);
