using FluentAssertions;
using IFX.BuildingBlocks.EntityFrameworkCore.Migrations;
using IFX.DatabaseMigrator;
using Xunit;

namespace IFX.DatabaseBoundary.Tests;

public sealed class SchemaCompatibilityTests
{
    [Fact]
    public void Release_schema_manifest_matches_versioned_migration_catalog()
    {
        var root = RepositoryRoot();
        var migrationPath = Path.Combine(root, "src", "DatabaseMigrator", "IFX.DatabaseMigrator", "migration-manifest.json");
        var migrationManifest = MigrationManifest.Load(migrationPath);
        var releaseManifest = LoadReleaseManifest();

        SchemaCompatibilityPlanner.ValidateManifest(releaseManifest).Should().BeEmpty();
        MigrationArtifactGenerator.ValidateReleaseManifest(migrationPath, migrationManifest, releaseManifest)
            .Should().BeEmpty();
        releaseManifest.Modules.Select(module => module.ModuleName)
            .Should().Equal("Auth", "CRM", "Registry", "Holdings", "Transaction");
    }

    [Fact]
    public void Required_schema_is_compatible()
    {
        var requirement = LoadReleaseManifest().Modules[0];

        var result = SchemaCompatibilityPlanner.Evaluate(requirement, requirement.RequiredMigrationIds.ToArray());

        result.IsCompatible.Should().BeTrue();
        result.Code.Should().Be("required-version");
    }

    [Fact]
    public void Newer_expand_compatible_schema_allows_old_release_to_remain_ready()
    {
        var requirement = LoadReleaseManifest().Modules[0] with
        {
            CompatibleAdditionalMigrationIds = ["20990101000000_FutureExpandOnly"]
        };
        var applied = requirement.RequiredMigrationIds.Append("20990101000000_FutureExpandOnly").ToArray();

        var result = SchemaCompatibilityPlanner.Evaluate(requirement, applied);

        result.IsCompatible.Should().BeTrue();
        result.Code.Should().Be("newer-expand-compatible");
        result.AdditionalMigrationIds.Should().ContainSingle("20990101000000_FutureExpandOnly");
    }

    [Fact]
    public void Unknown_newer_schema_fails_closed()
    {
        var requirement = LoadReleaseManifest().Modules[0];
        var applied = requirement.RequiredMigrationIds.Append("20990101000000_UnknownContract").ToArray();

        var result = SchemaCompatibilityPlanner.Evaluate(requirement, applied);

        result.IsCompatible.Should().BeFalse();
        result.Code.Should().Be("additional-migration-not-compatible");
    }

    [Fact]
    public void Missing_required_migration_is_not_ready()
    {
        var requirement = LoadReleaseManifest().Modules[0];

        var result = SchemaCompatibilityPlanner.Evaluate(requirement, requirement.RequiredMigrationIds.SkipLast(1).ToArray());

        result.IsCompatible.Should().BeFalse();
        result.Code.Should().Be("required-migration-missing");
        result.MissingMigrationIds.Should().ContainSingle(requirement.RequiredMigrationId);
    }

    [Fact]
    public void ApiHost_has_no_startup_DDL_path_and_carries_the_release_manifest()
    {
        var root = RepositoryRoot();
        var program = File.ReadAllText(Path.Combine(root, "src", "ApiHost", "IFX.ApiHost", "Program.cs"));
        var project = File.ReadAllText(Path.Combine(root, "src", "ApiHost", "IFX.ApiHost", "IFX.ApiHost.csproj"));

        program.Should().NotContain("GetServices<IAppMigrator>");
        program.Should().NotContain("MigrateAsync(");
        project.Should().Contain("deployment\\release-manifest.json");
        var healthChecks = File.ReadAllText(Path.Combine(
            root, "src", "ApiHost", "IFX.ApiHost", "Configuration", "HealthCheckConfiguration.cs"));
        healthChecks.Should().Contain("/health/database");
        healthChecks.Should().Contain("registration.Tags.Contains(\"database\")");
    }

    [Fact]
    public void Legacy_runtime_migrator_contract_and_module_implementations_are_removed()
    {
        var root = RepositoryRoot();
        File.Exists(Path.Combine(root, "src", "BuildingBlocks", "IFX.BuildingBlocks.Composition", "IAppMigrator.cs"))
            .Should().BeFalse();
        var moduleSources = Directory.EnumerateFiles(
            Path.Combine(root, "src", "Modules"),
            "*.cs",
            SearchOption.AllDirectories);

        foreach (var source in moduleSources)
        {
            var text = File.ReadAllText(source);
            text.Should().NotContain("IAppMigrator");
            text.Should().NotContain("Database.MigrateAsync(");
        }
    }

    [Theory]
    [InlineData("docker-compose.yml")]
    [InlineData("docker-compose.nas.yml")]
    public void Compose_requires_successful_one_shot_migrator_before_ApiHost(string composeFile)
    {
        var compose = File.ReadAllText(Path.Combine(RepositoryRoot(), composeFile));

        compose.Should().Contain("ifx-database-migrator:");
        compose.Should().Contain("condition: service_completed_successfully");
        compose.Should().Contain("MIGRATION_DB_USER");
        compose.Should().Contain("RUNTIME_DB_USER");
        compose.Should().Contain("restart: \"no\"");
        compose.IndexOf("ifx-database-migrator:", StringComparison.Ordinal)
            .Should().BeLessThan(compose.IndexOf("ifx-api:", StringComparison.Ordinal));
    }

    [Fact]
    public void Local_runtime_and_V3_CI_migration_commands_are_explicit()
    {
        var root = RepositoryRoot();
        File.Exists(Path.Combine(root, "scripts", "Invoke-DatabaseMigrator.ps1")).Should().BeTrue();
        File.Exists(Path.Combine(root, "docs", "guards", "V3_ifx", "stages", "post", "gates", "specialized", "scripts", "New-DatabaseMigrationArtifacts.ps1")).Should().BeTrue();
        File.Exists(Path.Combine(root, ".github", "workflows", "v3-ifx-guardrails.yml")).Should().BeTrue();
    }

    private static ReleaseSchemaManifest LoadReleaseManifest() => ReleaseSchemaManifest.Load(
        Path.Combine(RepositoryRoot(), "deployment", "release-manifest.json"));

    private static string RepositoryRoot()
    {
        var directory = new DirectoryInfo(AppContext.BaseDirectory);
        while (directory is not null && !File.Exists(Path.Combine(directory.FullName, "IFX.sln")))
        {
            directory = directory.Parent;
        }
        return directory?.FullName ?? throw new InvalidOperationException("Repository root not found.");
    }
}
