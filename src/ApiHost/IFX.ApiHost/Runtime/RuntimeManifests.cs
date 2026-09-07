using System.Text.Json;

namespace IFX.ApiHost.Runtime;

public sealed record ModuleManifest(int FormatVersion, string ReleaseVersion, IReadOnlyList<ModuleManifestEntry> Modules);

public sealed record ModuleManifestEntry(
    string ModuleId,
    string Version,
    bool Required,
    IReadOnlyList<string> Contracts,
    IReadOnlyList<string> EndpointGroups,
    string Schema,
    IReadOnlyList<string> Configuration,
    IReadOnlyList<string> RuntimeCapabilities,
    IReadOnlyList<string> ShutdownRequirements);

public sealed record ReleaseRuntimeManifest(
    int FormatVersion,
    string ReleaseId,
    string BusinessBoundary,
    HostArtifactManifest HostArtifact,
    IReadOnlyList<string> RequiredModuleIds);

public sealed record HostArtifactManifest(string ArtifactId, string Digest, IReadOnlyList<string> AllowedRoles);

public static class RuntimeManifestLoader
{
    private static readonly JsonSerializerOptions JsonOptions = new(JsonSerializerDefaults.Web)
    {
        PropertyNameCaseInsensitive = true
    };

    public static (ModuleManifest Modules, ReleaseRuntimeManifest Release) Load(string contentRoot)
    {
        var modules = Read<ModuleManifest>(Path.Combine(contentRoot, "module-manifest.json"), "G04-STARTUP-MODULE-MANIFEST-INVALID");
        var release = Read<ReleaseRuntimeManifest>(Path.Combine(contentRoot, "release-runtime-manifest.json"), "G04-STARTUP-RELEASE-MANIFEST-INVALID");
        return (modules, release);
    }

    private static T Read<T>(string path, string reasonCode)
    {
        try
        {
            using var stream = File.OpenRead(path);
            return JsonSerializer.Deserialize<T>(stream, JsonOptions)
                ?? throw new InvalidDataException("Manifest deserialized to null.");
        }
        catch (Exception exception) when (exception is IOException or JsonException or UnauthorizedAccessException)
        {
            throw new StartupValidationException(reasonCode, $"Unable to load runtime manifest '{Path.GetFileName(path)}'.", exception);
        }
    }
}
