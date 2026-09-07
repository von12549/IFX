using FluentAssertions;
using IFX.BuildingBlocks.EntityFrameworkCore.Migrations;
using Xunit;

namespace IFX.DatabaseBoundary.Tests;

public sealed class HistoryBootstrapPlannerTests
{
    private static readonly ModuleMigrationCatalog Auth = new(
        "Auth",
        "auth",
        10,
        ["20260327075710_InitialCreate", "20260327075811_InitialSeed"],
        ["Users", "Roles"]);

    private static readonly ModuleMigrationCatalog Crm = new(
        "CRM",
        "crm",
        20,
        ["20260401000000_CrmInitialCreate"],
        ["Clients"]);

    private static readonly IReadOnlyList<ModuleMigrationCatalog> Catalogs = [Auth, Crm];

    [Fact]
    public void Empty_database_is_fresh_and_needs_no_history_bootstrap()
    {
        var plan = HistoryBootstrapPlanner.Create(Catalogs, Snapshot());

        plan.Classification.Should().Be(HistoryBootstrapClassification.Fresh);
        plan.CanApply.Should().BeTrue();
        plan.HasChanges.Should().BeFalse();
        plan.Modules.Single(module => module.Module == "Auth").PendingMigrationIds
            .Should().Equal(Auth.MigrationIds);
    }

    [Fact]
    public void Shared_history_is_mapped_exactly_and_preserves_product_versions()
    {
        var authRow = Row(Auth.MigrationIds[0], "8.0.7");
        var crmRow = Row(Crm.MigrationIds[0], "8.0.11");
        var plan = HistoryBootstrapPlanner.Create(
            Catalogs,
            Snapshot(
                sharedExists: true,
                shared: [authRow, crmRow],
                schemaStates: CompleteSchemas()));

        plan.Classification.Should().Be(HistoryBootstrapClassification.CurrentSharedHistory);
        plan.CanApply.Should().BeTrue();
        plan.Modules.Should().HaveCount(2);
        plan.Modules.Single(module => module.Module == "Auth").RowsToInsert.Should().Equal(authRow);
        plan.Modules.Single(module => module.Module == "CRM").RowsToInsert.Should().Equal(crmRow);
        plan.Modules.Single(module => module.Module == "Auth").PendingMigrationIds
            .Should().Equal(Auth.MigrationIds[1]);
        plan.Modules.Single(module => module.Module == "CRM").PendingMigrationIds.Should().BeEmpty();
        plan.Modules.Should().OnlyContain(module => module.CreateHistoryTable);
    }

    [Fact]
    public void Repeated_bootstrap_is_an_idempotent_no_op()
    {
        var authRow = Row(Auth.MigrationIds[0], "8.0.7");
        var crmRow = Row(Crm.MigrationIds[0], "8.0.11");
        var histories = new Dictionary<string, ModuleHistoryState>
        {
            ["Auth"] = new(true, [authRow]),
            ["CRM"] = new(true, [crmRow])
        };
        var plan = HistoryBootstrapPlanner.Create(
            Catalogs,
            Snapshot(
                sharedExists: true,
                shared: [authRow, crmRow],
                histories: histories,
                schemaStates: CompleteSchemas()));

        plan.Classification.Should().Be(HistoryBootstrapClassification.AlreadyBootstrapped);
        plan.CanApply.Should().BeTrue();
        plan.HasChanges.Should().BeFalse();
    }

    [Fact]
    public void Unknown_shared_migration_fails_closed()
    {
        var plan = HistoryBootstrapPlanner.Create(
            Catalogs,
            Snapshot(sharedExists: true, shared: [Row("unknown", "8.0.0")]));

        plan.Classification.Should().Be(HistoryBootstrapClassification.Invalid);
        plan.CanApply.Should().BeFalse();
        plan.Errors.Should().Contain(error => error.Contains("unknown MigrationId 'unknown'"));
    }

    [Fact]
    public void Duplicate_migration_ownership_fails_closed()
    {
        var duplicate = Crm with { MigrationIds = [Auth.MigrationIds[0]] };
        var plan = HistoryBootstrapPlanner.Create([Auth, duplicate], Snapshot());

        plan.Classification.Should().Be(HistoryBootstrapClassification.Invalid);
        plan.Errors.Should().Contain(error => error.Contains("duplicate ownership"));
    }

    [Fact]
    public void Partial_schema_fingerprint_fails_closed()
    {
        var plan = HistoryBootstrapPlanner.Create(
            Catalogs,
            Snapshot(
                sharedExists: true,
                shared: [Row(Auth.MigrationIds[0], "8.0.7")],
                schemaStates: new Dictionary<string, ModuleSchemaState>
                {
                    ["Auth"] = ModuleSchemaState.Partial,
                    ["CRM"] = ModuleSchemaState.Absent
                }));

        plan.Classification.Should().Be(HistoryBootstrapClassification.Invalid);
        plan.Errors.Should().Contain(error => error.Contains("fingerprint is partial"));
    }

    [Fact]
    public void Complete_schema_without_recognized_history_requires_explicit_adoption()
    {
        var plan = HistoryBootstrapPlanner.Create(
            Catalogs,
            Snapshot(schemaStates: new Dictionary<string, ModuleSchemaState>
            {
                ["Auth"] = ModuleSchemaState.Complete,
                ["CRM"] = ModuleSchemaState.Absent
            }));

        plan.Classification.Should().Be(HistoryBootstrapClassification.ExplicitAdoptionRequired);
        plan.CanApply.Should().BeFalse();
    }

    [Fact]
    public void Product_version_conflict_fails_closed()
    {
        var id = Auth.MigrationIds[0];
        var plan = HistoryBootstrapPlanner.Create(
            Catalogs,
            Snapshot(
                sharedExists: true,
                shared: [Row(id, "8.0.7")],
                histories: new Dictionary<string, ModuleHistoryState>
                {
                    ["Auth"] = new(true, [Row(id, "8.0.11")])
                },
                schemaStates: new Dictionary<string, ModuleSchemaState>
                {
                    ["Auth"] = ModuleSchemaState.Complete,
                    ["CRM"] = ModuleSchemaState.Absent
                }));

        plan.Classification.Should().Be(HistoryBootstrapClassification.Invalid);
        plan.Errors.Should().Contain(error => error.Contains("ProductVersion conflicts"));
    }

    [Fact]
    public void Module_history_with_foreign_id_fails_closed()
    {
        var plan = HistoryBootstrapPlanner.Create(
            Catalogs,
            Snapshot(
                histories: new Dictionary<string, ModuleHistoryState>
                {
                    ["Auth"] = new(true, [Row(Crm.MigrationIds[0], "8.0.11")])
                },
                schemaStates: new Dictionary<string, ModuleSchemaState>
                {
                    ["Auth"] = ModuleSchemaState.Complete,
                    ["CRM"] = ModuleSchemaState.Absent
                }));

        plan.Classification.Should().Be(HistoryBootstrapClassification.Invalid);
        plan.Errors.Should().Contain(error => error.Contains("foreign or unknown MigrationId"));
    }

    [Fact]
    public void Duplicate_target_history_rows_fail_closed_without_planner_failure()
    {
        var row = Row(Auth.MigrationIds[0], "8.0.7");
        var action = () => HistoryBootstrapPlanner.Create(
            Catalogs,
            Snapshot(
                histories: new Dictionary<string, ModuleHistoryState>
                {
                    ["Auth"] = new(true, [row, row])
                },
                schemaStates: new Dictionary<string, ModuleSchemaState>
                {
                    ["Auth"] = ModuleSchemaState.Complete,
                    ["CRM"] = ModuleSchemaState.Absent
                }));

        var plan = action.Should().NotThrow().Which;
        plan.Classification.Should().Be(HistoryBootstrapClassification.Invalid);
        plan.Errors.Should().Contain(error => error.Contains("duplicate MigrationId"));
    }

    private static MigrationHistoryRow Row(string id, string version) => new(id, version);

    private static Dictionary<string, ModuleSchemaState> CompleteSchemas() => new()
    {
        ["Auth"] = ModuleSchemaState.Complete,
        ["CRM"] = ModuleSchemaState.Complete
    };

    private static HistoryBootstrapSnapshot Snapshot(
        bool sharedExists = false,
        IReadOnlyList<MigrationHistoryRow>? shared = null,
        IReadOnlyDictionary<string, ModuleHistoryState>? histories = null,
        IReadOnlyDictionary<string, ModuleSchemaState>? schemaStates = null) =>
        new(
            sharedExists,
            shared ?? [],
            histories ?? new Dictionary<string, ModuleHistoryState>(),
            schemaStates ?? new Dictionary<string, ModuleSchemaState>());
}
