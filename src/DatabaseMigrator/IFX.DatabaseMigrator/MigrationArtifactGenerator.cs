using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using IFX.BuildingBlocks.EntityFrameworkCore.Migrations;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Migrations;

namespace IFX.DatabaseMigrator;

public static class MigrationArtifactGenerator
{
    private const string DesignConnection =
        "Server=localhost;Database=IFXDb;Integrated Security=true;TrustServerCertificate=true";

    public static async Task<MigrationArtifactReport> GenerateAsync(
        string migrationManifestPath,
        MigrationManifest migrationManifest,
        ReleaseSchemaManifest releaseManifest,
        string releaseManifestPath,
        string outputDirectory,
        CancellationToken cancellationToken)
    {
        Directory.CreateDirectory(outputDirectory);
        var contexts = ModuleRuntime.All.ToDictionary(
            runtime => runtime.ModuleName,
            runtime => runtime.CreateContext(DesignConnection),
            StringComparer.Ordinal);
        try
        {
            var errors = MigrationManifestValidator.Validate(migrationManifest, ModuleRuntime.All, contexts)
                .Concat(SchemaCompatibilityPlanner.ValidateManifest(releaseManifest))
                .Concat(ValidateReleaseManifest(migrationManifestPath, migrationManifest, releaseManifest))
                .ToArray();
            if (errors.Length > 0)
            {
                throw new InvalidOperationException($"Migration artifact validation failed: {string.Join(" ", errors)}");
            }

            var artifacts = new List<MigrationArtifact>();
            foreach (var runtime in ModuleRuntime.All.OrderBy(runtime => runtime.Order))
            {
                var script = contexts[runtime.ModuleName]
                    .GetService<IMigrator>()
                    .GenerateScript(options: MigrationsSqlGenerationOptions.Idempotent)
                    .ReplaceLineEndings("\n");
                var fileName = $"{runtime.Order:D2}-{runtime.ModuleName.ToLowerInvariant()}.idempotent.sql";
                var path = Path.Combine(outputDirectory, fileName);
                await File.WriteAllTextAsync(path, script, cancellationToken);
                artifacts.Add(new MigrationArtifact(runtime.ModuleName, fileName, Sha256(path)));
            }

            File.Copy(migrationManifestPath, Path.Combine(outputDirectory, "migration-manifest.json"), true);
            File.Copy(releaseManifestPath, Path.Combine(outputDirectory, "release-manifest.json"), true);
            var report = new MigrationArtifactReport(
                releaseManifest.ReleaseVersion,
                releaseManifest.MigrationCatalogSha256,
                artifacts);
            await File.WriteAllTextAsync(
                Path.Combine(outputDirectory, "artifact-manifest.json"),
                JsonSerializer.Serialize(report, ReleaseSchemaManifest.JsonOptions) + Environment.NewLine,
                cancellationToken);
            return report;
        }
        finally
        {
            foreach (var context in contexts.Values) await context.DisposeAsync();
        }
    }

    public static IReadOnlyList<string> ValidateReleaseManifest(
        string migrationManifestPath,
        MigrationManifest migrationManifest,
        ReleaseSchemaManifest releaseManifest)
    {
        var errors = new List<string>();
        if (!releaseManifest.MigrationCatalogSha256.Equals(Sha256NormalizedText(migrationManifestPath), StringComparison.OrdinalIgnoreCase))
        {
            errors.Add("Release manifest migration catalog hash does not match migration-manifest.json.");
        }

        foreach (var module in migrationManifest.Modules)
        {
            var requirement = releaseManifest.Modules.SingleOrDefault(candidate => candidate.ModuleName == module.ModuleName);
            if (requirement is null)
            {
                errors.Add($"Release manifest is missing module '{module.ModuleName}'.");
                continue;
            }
            var ids = module.Migrations.Select(migration => migration.MigrationId).ToArray();
            if (requirement.Schema != module.Schema ||
                requirement.HistoryTable != module.HistoryTable ||
                requirement.RuntimeConnectionKey != module.ConnectionKey ||
                !requirement.RequiredMigrationIds.SequenceEqual(ids, StringComparer.Ordinal))
            {
                errors.Add($"Release schema metadata does not match migration module '{module.ModuleName}'.");
            }
        }
        return errors;
    }

    private static string Sha256(string path)
    {
        using var stream = File.OpenRead(path);
        return Convert.ToHexString(SHA256.HashData(stream)).ToLowerInvariant();
    }

    private static string Sha256NormalizedText(string path)
    {
        var normalized = File.ReadAllText(path).ReplaceLineEndings("\n");
        return Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(normalized))).ToLowerInvariant();
    }
}

public sealed record MigrationArtifactReport(
    string ReleaseVersion,
    string MigrationCatalogSha256,
    IReadOnlyList<MigrationArtifact> Scripts);

public sealed record MigrationArtifact(string Module, string File, string Sha256);
