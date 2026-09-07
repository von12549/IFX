using System.Text.Json;

namespace IFX.BuildingBlocks.EntityFrameworkCore.Migrations;

public sealed record ReleaseSchemaManifest(
    int FormatVersion,
    string ReleaseVersion,
    string MigrationCatalogSha256,
    IReadOnlyList<ModuleSchemaRequirement> Modules)
{
    public static ReleaseSchemaManifest Load(string path)
    {
        using var stream = File.OpenRead(path);
        return JsonSerializer.Deserialize<ReleaseSchemaManifest>(stream, JsonOptions)
               ?? throw new InvalidOperationException("Release schema manifest is empty.");
    }

    public static JsonSerializerOptions JsonOptions { get; } = new()
    {
        PropertyNameCaseInsensitive = true,
        WriteIndented = true
    };
}

public sealed record ModuleSchemaRequirement(
    string ModuleName,
    string Schema,
    string HistoryTable,
    string RuntimeConnectionKey,
    string RequiredMigrationId,
    IReadOnlyList<string> RequiredMigrationIds,
    IReadOnlyList<string> CompatibleAdditionalMigrationIds);

public sealed record ModuleSchemaCompatibility(
    string ModuleName,
    bool IsCompatible,
    string Code,
    string? CurrentMigrationId,
    IReadOnlyList<string> MissingMigrationIds,
    IReadOnlyList<string> AdditionalMigrationIds);
