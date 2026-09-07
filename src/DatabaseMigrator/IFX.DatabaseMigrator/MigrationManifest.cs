using System.Text.Json;

namespace IFX.DatabaseMigrator;

public sealed record MigrationManifest(
    int FormatVersion,
    string PhysicalDatabase,
    IReadOnlyList<ModuleManifest> Modules)
{
    public static MigrationManifest Load(string path)
    {
        using var stream = File.OpenRead(path);
        return JsonSerializer.Deserialize<MigrationManifest>(stream, JsonOptions)
               ?? throw new InvalidOperationException("Migration manifest is empty.");
    }

    private static JsonSerializerOptions JsonOptions { get; } = new()
    {
        PropertyNameCaseInsensitive = true
    };
}

public sealed record ModuleManifest(
    string ModuleName,
    string DbContext,
    string Schema,
    string HistoryTable,
    string ConnectionKey,
    int Order,
    IReadOnlyList<string> DependsOn,
    IReadOnlyList<MigrationManifestEntry> Migrations);

public sealed record MigrationManifestEntry(
    string MigrationId,
    string ProductVersion,
    string SourceSha256);
