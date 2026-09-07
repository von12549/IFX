using System.Text.Json;
using FluentAssertions;
using Xunit;

namespace IFX.DatabaseBoundary.Tests;

public sealed class MigrationSafetyPolicyTests
{
    [Fact]
    public void Every_high_risk_migration_has_a_hash_bound_review_record()
    {
        var root = RepositoryRoot();
        using var inventory = JsonDocument.Parse(File.ReadAllText(Path.Combine(
            root, "docs", "architecture", "review", "evidence", "gates", "G02", "G02-database-inventory.json")));
        using var policy = JsonDocument.Parse(File.ReadAllText(Path.Combine(
            root, "deployment", "migration-safety-policy.json")));
        var reviews = policy.RootElement.GetProperty("reviewedMigrations").EnumerateArray().ToArray();

        policy.RootElement.GetProperty("defaultStrategy").GetString().Should().Be("roll-forward");
        policy.RootElement.GetProperty("automaticDownAllowed").GetBoolean().Should().BeFalse();
        foreach (var module in inventory.RootElement.GetProperty("modules").EnumerateArray())
        {
            var moduleName = module.GetProperty("Module").GetString();
            foreach (var migration in module.GetProperty("Migrations").EnumerateArray()
                         .Where(item => item.GetProperty("Risk").GetProperty("Level").GetString() == "high"))
            {
                var id = migration.GetProperty("MigrationId").GetString();
                var hash = migration.GetProperty("SourceSha256").GetString();
                reviews.Where(review =>
                        review.GetProperty("module").GetString() == moduleName &&
                        review.GetProperty("migrationId").GetString() == id)
                    .Should().ContainSingle()
                    .Which.GetProperty("sourceSha256").GetString().Should().Be(hash);
            }
        }
    }

    [Fact]
    public void Database_runtime_contains_no_automatic_targeted_Down_execution()
    {
        var root = RepositoryRoot();
        var sources = Directory.EnumerateFiles(
                Path.Combine(root, "src", "DatabaseMigrator"),
                "*.cs",
                SearchOption.AllDirectories)
            .Concat([Path.Combine(root, "src", "ApiHost", "IFX.ApiHost", "Program.cs")]);

        foreach (var source in sources)
        {
            var text = File.ReadAllText(source);
            text.Should().NotContain("MigrateAsync(\"");
            text.Should().NotContain("Migrate(\"");
        }
    }

    [Fact]
    public void Recovery_and_audit_templates_define_required_controls()
    {
        var root = RepositoryRoot();
        var recovery = File.ReadAllText(Path.Combine(
            root, "docs", "architecture", "review", "evidence", "gates", "G02", "G02-phase6-recovery-runbook.md"));
        var expandContract = File.ReadAllText(Path.Combine(
            root, "docs", "architecture", "review", "evidence", "gates", "G02", "G02-phase6-expand-contract-template.md"));
        using var audit = JsonDocument.Parse(File.ReadAllText(Path.Combine(
            root, "deployment", "database-upgrade-audit-template.json")));

        recovery.Should().ContainAll("Application-lock timeout", "Process termination", "Connection interruption", "Post-validation failure");
        recovery.Should().Contain("Do not invoke EF `Down` automatically");
        expandContract.Should().ContainAll("## 1. Expand", "## 2. Deploy and read transition", "## 3. Write transition", "## 4. Backfill", "## 5. Contract");
        audit.RootElement.GetProperty("artifacts").GetProperty("migrationManifestSha256").GetString().Should().NotBeNullOrWhiteSpace();
        audit.RootElement.GetProperty("restorePoint").GetProperty("identifier").GetString().Should().NotBeNullOrWhiteSpace();
        audit.RootElement.GetProperty("execution").GetProperty("validationReport").GetString().Should().NotBeNullOrWhiteSpace();
        audit.RootElement.GetProperty("recovery").GetProperty("nextReleaseCondition").GetString().Should().NotBeNullOrWhiteSpace();
    }

    [Fact]
    public void Rollout_evidence_template_requires_every_external_phase_8_control()
    {
        using var evidence = JsonDocument.Parse(File.ReadAllText(Path.Combine(
            RepositoryRoot(), "deployment", "database-rollout-evidence-template.json")));
        var root = evidence.RootElement;

        root.GetProperty("preflight").GetProperty("historyMappingReviewed").GetBoolean().Should().BeFalse();
        root.GetProperty("preflight").GetProperty("fingerprintReviewed").GetBoolean().Should().BeFalse();
        root.GetProperty("restorePoint").GetProperty("restoreVerified").GetBoolean().Should().BeFalse();
        root.GetProperty("execution").GetProperty("validationResult").GetString().Should().Be("<succeeded>");
        root.GetProperty("compatibilityWindow").GetProperty("rollbackCompatibilityVerified").GetBoolean().Should().BeFalse();
        root.GetProperty("runtimeIdentity").GetProperty("ddlDenied").GetBoolean().Should().BeFalse();
        root.GetProperty("sharedHistory").GetProperty("mode").GetString().Should().Be("<archived-read-only-or-not-present-fresh>");
        File.Exists(Path.Combine(RepositoryRoot(), "scripts", "Test-G02DatabaseRolloutEvidence.ps1"))
            .Should().BeTrue();
    }

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
