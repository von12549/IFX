using FluentAssertions;
using IFX.BuildingBlocks.EntityFrameworkCore.Migrations;
using IFX.Modules.IAM.Infrastructure.Persistence;
using IFX.Modules.IAM.Infrastructure.Persistence.Migrations.Legacy;
using Microsoft.EntityFrameworkCore;
using Xunit;

namespace IFX.DatabaseBoundary.Tests;

public sealed class AuthLegacyAdoptionTests
{
    private const string ProductVersion = "8.0.0";
    private static readonly IReadOnlyCollection<string> CurrentIds =
    [
        AuthLegacyMigrationManifest.CanonicalInitialCreateId,
        "20260327075811_InitialSeed",
        "20260413100000_CrmPolicyDefinitionSeeds",
        "20260420042950_AlterAuditColumnsToDateTimeOffset"
    ];

    [Fact]
    public void Canonical_history_is_already_normalized_and_idempotent()
    {
        var canonical = Row(AuthLegacyMigrationManifest.CanonicalInitialCreateId);

        var plan = Plan([], [canonical], fingerprintMatches: true);

        plan.Classification.Should().Be(AuthLegacyAdoptionClassification.AlreadyCanonical);
        plan.CanApply.Should().BeTrue();
        plan.HasChanges.Should().BeFalse();
    }

    [Fact]
    public void Exact_fourteen_id_shared_legacy_is_adopted_without_mutating_shared_rows()
    {
        var shared = AuthLegacyMigrationManifest.PreSquashMigrationIds.Select(Row).ToArray();

        var plan = Plan(shared, [], fingerprintMatches: true);

        plan.Classification.Should().Be(AuthLegacyAdoptionClassification.PreSquashHistory);
        plan.TargetRowsToDelete.Should().BeEmpty();
        plan.CanonicalRowToInsert.Should().Be(Row(AuthLegacyMigrationManifest.CanonicalInitialCreateId));
    }

    [Fact]
    public void Exact_fourteen_id_target_legacy_is_replaced_atomically()
    {
        var target = AuthLegacyMigrationManifest.PreSquashMigrationIds.Select(Row).ToArray();

        var plan = Plan([], target, fingerprintMatches: true);

        plan.Classification.Should().Be(AuthLegacyAdoptionClassification.PreSquashHistory);
        plan.TargetRowsToDelete.Should().BeEquivalentTo(AuthLegacyMigrationManifest.PreSquashMigrationIds);
        plan.CanonicalRowToInsert.Should().NotBeNull();
    }

    [Fact]
    public void Incorrect_squash_id_is_only_a_legacy_alias()
    {
        var plan = Plan(
            [Row(AuthLegacyMigrationManifest.IncorrectSquashAlias)],
            [],
            fingerprintMatches: true);

        plan.Classification.Should().Be(AuthLegacyAdoptionClassification.IncorrectSquashAlias);
        plan.CanonicalRowToInsert!.MigrationId.Should()
            .Be(AuthLegacyMigrationManifest.CanonicalInitialCreateId);
    }

    [Fact]
    public void Partial_legacy_history_fails_closed()
    {
        var partial = AuthLegacyMigrationManifest.PreSquashMigrationIds.Take(13).Select(Row).ToArray();

        var plan = Plan(partial, [], fingerprintMatches: true);

        plan.Classification.Should().Be(AuthLegacyAdoptionClassification.Invalid);
        plan.CanApply.Should().BeFalse();
        plan.Errors.Should().Contain(error => error.Contains("mixed or incomplete"));
    }

    [Fact]
    public void Fingerprint_mismatch_fails_closed_without_history_changes()
    {
        var legacy = AuthLegacyMigrationManifest.PreSquashMigrationIds.Select(Row).ToArray();

        var plan = Plan(legacy, [], fingerprintMatches: false);

        plan.Classification.Should().Be(AuthLegacyAdoptionClassification.Invalid);
        plan.HasChanges.Should().BeFalse();
        plan.Errors.Should().Contain(error => error.Contains("fingerprint does not match"));
    }

    [Fact]
    public void Complete_historyless_schema_requires_explicit_adoption()
    {
        var plan = Plan([], [], fingerprintMatches: true, explicitAdoption: false);

        plan.Classification.Should().Be(AuthLegacyAdoptionClassification.ExplicitAdoptionRequired);
        plan.CanApply.Should().BeFalse();
        plan.HasChanges.Should().BeFalse();
    }

    [Fact]
    public void Explicit_ensure_created_adoption_stamps_the_real_canonical_id()
    {
        var plan = Plan([], [], fingerprintMatches: true, explicitAdoption: true);

        plan.Classification.Should().Be(AuthLegacyAdoptionClassification.EnsureCreatedAdoption);
        plan.CanApply.Should().BeTrue();
        plan.CanonicalRowToInsert!.MigrationId.Should()
            .Be("20260327075710_InitialCreate");
    }

    [Fact]
    public void Baseline_fingerprint_covers_tables_columns_keys_foreign_keys_and_indexes()
    {
        using var context = CreateContext();

        var fingerprint = AuthBaselineSchemaFingerprint.Create(context);

        fingerprint.Schema.Should().Be("auth");
        fingerprint.Tables.Should().HaveCountGreaterThan(10);
        fingerprint.Tables.Should().OnlyContain(table => table.Columns.Count > 0 && table.Keys.Count > 0);
        fingerprint.Tables.SelectMany(table => table.ForeignKeys).Should().NotBeEmpty();
        fingerprint.Tables.SelectMany(table => table.Indexes).Should().NotBeEmpty();
        fingerprint.Sha256().Should().MatchRegex("^[0-9a-f]{64}$");
    }

    [Fact]
    public void Missing_column_changes_the_full_fingerprint()
    {
        using var context = CreateContext();
        var expected = AuthBaselineSchemaFingerprint.Create(context);
        var first = expected.Tables[0];
        var changed = expected with
        {
            Tables =
            [
                first with { Columns = first.Columns.Skip(1).ToArray() },
                .. expected.Tables.Skip(1)
            ]
        };

        var result = SchemaFingerprintComparer.Verify(expected, changed);

        result.Matches.Should().BeFalse();
        result.Differences.Should().Contain(difference => difference.StartsWith("Missing "));
    }

    [Fact]
    public void Generic_bootstrap_requires_auth_legacy_normalization_then_accepts_canonical_target()
    {
        var catalog = new ModuleMigrationCatalog(
            "Auth",
            "auth",
            10,
            CurrentIds.ToArray(),
            ["Users"],
            AuthLegacyMigrationManifest.AllLegacyIds);
        var shared = AuthLegacyMigrationManifest.PreSquashMigrationIds.Select(Row).ToArray();
        var before = HistoryBootstrapPlanner.Create(
            [catalog],
            new(
                true,
                shared,
                new Dictionary<string, ModuleHistoryState>(),
                new Dictionary<string, ModuleSchemaState> { ["Auth"] = ModuleSchemaState.Complete }));
        var after = HistoryBootstrapPlanner.Create(
            [catalog],
            new(
                true,
                shared,
                new Dictionary<string, ModuleHistoryState>
                {
                    ["Auth"] = new(true, [Row(AuthLegacyMigrationManifest.CanonicalInitialCreateId)])
                },
                new Dictionary<string, ModuleSchemaState> { ["Auth"] = ModuleSchemaState.Complete }));

        before.CanApply.Should().BeFalse();
        before.Errors.Should().Contain(error => error.Contains("requires normalization"));
        after.CanApply.Should().BeTrue();
        after.HasChanges.Should().BeFalse();
    }

    private static AuthLegacyAdoptionPlan Plan(
        IReadOnlyList<MigrationHistoryRow> source,
        IReadOnlyList<MigrationHistoryRow> target,
        bool fingerprintMatches,
        bool explicitAdoption = false) =>
        AuthLegacyAdoptionPlanner.Create(
            source,
            target,
            CurrentIds,
            [],
            ProductVersion,
            fingerprintMatches,
            explicitAdoption);

    private static MigrationHistoryRow Row(string id) => new(id, ProductVersion);

    private static IfxDbContext CreateContext()
    {
        var options = new DbContextOptionsBuilder<IfxDbContext>()
            .UseSqlServer("Server=localhost;Database=FingerprintOnly;Integrated Security=true;TrustServerCertificate=true")
            .Options;
        return new IfxDbContext(options);
    }
}
