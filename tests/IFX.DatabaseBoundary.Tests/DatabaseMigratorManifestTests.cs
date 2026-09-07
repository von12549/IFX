using FluentAssertions;
using IFX.DatabaseMigrator;
using Microsoft.EntityFrameworkCore;
using Xunit;

namespace IFX.DatabaseBoundary.Tests;

public sealed class DatabaseMigratorManifestTests
{
    private const string TestConnection =
        "Server=localhost;Database=ManifestOnly;Integrated Security=true;TrustServerCertificate=true";

    [Fact]
    public void Versioned_manifest_matches_all_runtime_migration_assemblies()
    {
        var manifest = LoadManifest();
        using var contexts = ContextSet.Create();

        var errors = MigrationManifestValidator.Validate(manifest, ModuleRuntime.All, contexts.Items);

        errors.Should().BeEmpty();
        manifest.Modules.Select(module => module.ModuleName)
            .Should().Equal("Auth", "CRM", "Registry", "Holdings", "Transaction");
        manifest.Modules.SelectMany(module => module.Migrations).Should().HaveCount(14);
    }

    [Fact]
    public void Duplicate_order_fails_manifest_validation()
    {
        var manifest = LoadManifest();
        var changed = manifest with
        {
            Modules =
            [
                manifest.Modules[0],
                manifest.Modules[1] with { Order = manifest.Modules[0].Order },
                .. manifest.Modules.Skip(2)
            ]
        };
        using var contexts = ContextSet.Create();

        var errors = MigrationManifestValidator.Validate(changed, ModuleRuntime.All, contexts.Items);

        errors.Should().Contain(error => error.Contains("Duplicate module order"));
    }

    [Fact]
    public void Missing_module_fails_manifest_validation()
    {
        var manifest = LoadManifest() with { Modules = LoadManifest().Modules.Skip(1).ToArray() };
        using var contexts = ContextSet.Create();

        var errors = MigrationManifestValidator.Validate(manifest, ModuleRuntime.All, contexts.Items);

        errors.Should().Contain(error => error.Contains("missing module 'Auth'"));
    }

    [Fact]
    public void Cyclic_dependencies_fail_manifest_validation()
    {
        var manifest = LoadManifest();
        var changed = manifest with
        {
            Modules =
            [
                manifest.Modules[0] with { DependsOn = ["CRM"] },
                manifest.Modules[1] with { DependsOn = ["Auth"] },
                .. manifest.Modules.Skip(2)
            ]
        };
        using var contexts = ContextSet.Create();

        var errors = MigrationManifestValidator.Validate(changed, ModuleRuntime.All, contexts.Items);

        errors.Should().Contain("Manifest dependency graph contains a cycle.");
    }

    [Theory]
    [InlineData("preflight", MigratorMode.Preflight)]
    [InlineData("dry-run", MigratorMode.DryRun)]
    [InlineData("apply", MigratorMode.Apply)]
    [InlineData("validate", MigratorMode.Validate)]
    [InlineData("scripts", MigratorMode.Scripts)]
    public void Command_line_exposes_each_required_mode(string value, MigratorMode expected)
    {
        MigratorOptions.Parse(["--mode", value]).Mode.Should().Be(expected);
    }

    [Fact]
    public void Dry_run_shortcut_is_supported()
    {
        MigratorOptions.Parse(["--dry-run"]).Mode.Should().Be(MigratorMode.DryRun);
    }

    [Fact]
    public void Runtime_order_is_explicit_and_stable()
    {
        ModuleRuntime.All.Select(runtime => (runtime.ModuleName, runtime.Order)).Should().Equal(
            ("Auth", 10),
            ("CRM", 20),
            ("Registry", 30),
            ("Holdings", 40),
            ("Transaction", 50));
    }

    [Fact]
    public void Migrator_project_is_an_executable_without_web_or_composition_dependencies()
    {
        var project = File.ReadAllText(Path.Combine(
            RepositoryRoot(),
            "src",
            "DatabaseMigrator",
            "IFX.DatabaseMigrator",
            "IFX.DatabaseMigrator.csproj"));

        project.Should().Contain("<OutputType>Exe</OutputType>");
        project.Should().NotContain("Microsoft.AspNetCore");
        project.Should().NotContain(".Composition");
        project.Should().NotContain("BackgroundJobs");
    }

    private static MigrationManifest LoadManifest() => MigrationManifest.Load(
        Path.Combine(RepositoryRoot(), "src", "DatabaseMigrator", "IFX.DatabaseMigrator", "migration-manifest.json"));

    private static string RepositoryRoot()
    {
        var directory = new DirectoryInfo(AppContext.BaseDirectory);
        while (directory is not null && !File.Exists(Path.Combine(directory.FullName, "IFX.sln")))
        {
            directory = directory.Parent;
        }
        return directory?.FullName ?? throw new InvalidOperationException("Repository root not found.");
    }

    private sealed class ContextSet : IDisposable
    {
        private ContextSet(IReadOnlyDictionary<string, DbContext> items) => Items = items;

        public IReadOnlyDictionary<string, DbContext> Items { get; }

        public static ContextSet Create() => new(ModuleRuntime.All.ToDictionary(
            runtime => runtime.ModuleName,
            runtime => runtime.CreateContext(TestConnection),
            StringComparer.Ordinal));

        public void Dispose()
        {
            foreach (var context in Items.Values) context.Dispose();
        }
    }
}
