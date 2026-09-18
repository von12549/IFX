using System.Security.Cryptography;
using System.Text;
using System.Text.Json;

namespace LayerGuard;

/// One artifact a policy binding verified, as it appears in the report.
public sealed record PolicyBindingInfo(string Gate, string Source, string Sha256);

public sealed record WaiverPolicyInfo(
    int MaximumDays,
    IReadOnlyList<string> UnwaivableCategories,
    IReadOnlyList<string> UnwaivableRules
);

/// A file that takes part in the composite policy hash, under the label the report shows.
public sealed record PolicyBindingFile(string Label, string Path);

/// What a policy binding contributes to the ruleset: the provider graph and shared primitives it admits, the artifacts
/// it verified, the waiver policy it imposes, and the files whose content the composite policy hash covers.
public sealed record PolicyBindingResult(
    IReadOnlyDictionary<string, string[]> ProviderContracts,
    IReadOnlyList<string> SharedPrimitiveProjects,
    IReadOnlyList<PolicyBindingInfo> Bindings,
    WaiverPolicyInfo? WaiverPolicy,
    IReadOnlyList<PolicyBindingFile> HashedFiles
);

/// A repository binds its own governance artifacts to the engine through this interface (Plan 06 P6.3, D27). The engine
/// hands over the configuration section named by `Section` without reading it; every rule inside belongs to the binding.
public interface IPolicyBinding
{
    string Section { get; }

    PolicyBindingResult Load(JsonElement section, JsonElement config, string configPath);
}

/// The bindings a host registered before analysis. A host that registers none can still analyze configurations that
/// bind nothing; a configuration that names a section without a binding fails closed.
public static class PolicyBindings
{
    private static readonly Dictionary<string, IPolicyBinding> Registered = new(StringComparer.OrdinalIgnoreCase);

    public static void Register(IPolicyBinding binding)
    {
        ArgumentNullException.ThrowIfNull(binding);
        lock (Registered) { Registered[binding.Section] = binding; }
    }

    public static IPolicyBinding? Find(string section)
    {
        lock (Registered) { return Registered.TryGetValue(section, out var binding) ? binding : null; }
    }
}

/// Reading helpers for bindings: strict JSON access, artifact resolution and the hash rules the report depends on.
public static class PolicyDocument
{
    private static readonly JsonDocumentOptions JsonOptions = new()
    {
        AllowTrailingCommas = true,
        CommentHandling = JsonCommentHandling.Skip,
    };

    public static JsonDocument Parse(string path, string label)
    {
        try { return JsonDocument.Parse(File.ReadAllText(path), JsonOptions); }
        catch (Exception error) { throw new InvalidDataException($"Cannot read {label} `{path}`: {error.Message}", error); }
    }

    public static void RequireVersion(JsonElement root, string path)
    {
        if (!root.TryGetProperty("formatVersion", out var version) || version.GetInt32() != 1)
            throw new InvalidDataException($"{path} requires formatVersion 1.");
    }

    public static string RequiredString(JsonElement element, string property, string path)
    {
        if (!element.TryGetProperty(property, out var value) || value.ValueKind != JsonValueKind.String
            || string.IsNullOrWhiteSpace(value.GetString()))
            throw new InvalidDataException($"{path} requires non-empty `{property}`.");
        return value.GetString()!;
    }

    public static int RequiredInt(JsonElement element, string property, string path)
    {
        if (!element.TryGetProperty(property, out var value) || value.ValueKind != JsonValueKind.Number)
            throw new InvalidDataException($"{path} requires numeric `{property}`.");
        return value.GetInt32();
    }

    public static JsonElement RequiredObject(JsonElement element, string property, string path)
    {
        if (!element.TryGetProperty(property, out var value) || value.ValueKind != JsonValueKind.Object)
            throw new InvalidDataException($"{path} requires object `{property}`.");
        return value;
    }

    public static JsonElement RequiredArray(JsonElement element, string property, string path)
    {
        if (!element.TryGetProperty(property, out var value) || value.ValueKind != JsonValueKind.Array)
            throw new InvalidDataException($"{path} requires array `{property}`.");
        return value;
    }

    public static IReadOnlyDictionary<string, string[]> ReadProviderGraph(JsonElement element, string path)
    {
        var result = new Dictionary<string, string[]>(StringComparer.OrdinalIgnoreCase);
        foreach (var consumer in element.EnumerateObject())
        {
            var providers = consumer.Value.EnumerateArray()
                .Select(item => item.GetString())
                .Where(item => !string.IsNullOrWhiteSpace(item))
                .Select(item => item!)
                .Distinct(StringComparer.OrdinalIgnoreCase)
                .ToArray();
            if (providers.Length == 0)
                throw new InvalidDataException($"{path} provider graph consumer `{consumer.Name}` has no providers.");
            result.Add(consumer.Name, providers);
        }
        if (result.Count == 0)
            throw new InvalidDataException($"{path} contains an empty provider graph.");
        return result;
    }

    public static void RequireSameSet(IEnumerable<string> expected, IEnumerable<string> actual, string label, string path)
    {
        var expectedSet = expected.ToHashSet(StringComparer.OrdinalIgnoreCase);
        var actualSet = actual.ToHashSet(StringComparer.OrdinalIgnoreCase);
        if (!expectedSet.SetEquals(actualSet))
            throw new InvalidDataException(
                $"{path} {label} drifted from the catalog. Missing: [{string.Join(", ", expectedSet.Except(actualSet))}]; "
                + $"unexpected: [{string.Join(", ", actualSet.Except(expectedSet))}]."
            );
    }

    /// Resolves an artifact reference against the configuration file, upwards, so a policy may name repository artifacts.
    public static string Resolve(string configPath, string reference)
    {
        if (Path.IsPathRooted(reference))
        {
            var rooted = Paths.Normalize(reference);
            if (File.Exists(rooted)) return rooted;
            throw new FileNotFoundException($"Bound Gate artifact does not exist: {rooted}", rooted);
        }

        for (var directory = new FileInfo(configPath).Directory; directory is not null; directory = directory.Parent)
        {
            var candidate = Path.GetFullPath(Path.Combine(directory.FullName, reference));
            if (File.Exists(candidate)) return candidate;
        }
        throw new FileNotFoundException($"Cannot resolve bound Gate artifact `{reference}` from `{configPath}`.");
    }

    public static void VerifyHash(string path, string expected, string label)
    {
        var actual = RawHash(path);
        if (!actual.Equals(expected, StringComparison.OrdinalIgnoreCase) &&
            !CanonicalTextHash(path).Equals(expected, StringComparison.OrdinalIgnoreCase))
            throw new InvalidDataException($"{label} hash mismatch for `{path}`: expected {expected}, actual {actual}.");
    }

    public static string RawHash(string path) =>
        Convert.ToHexString(SHA256.HashData(File.ReadAllBytes(path))).ToLowerInvariant();

    // Governed text artifacts are generated with LF in Git. A Windows checkout may materialize
    // the same committed content as CRLF, which must not invalidate the binding. Raw bytes are
    // checked first; this fallback removes only CR bytes that precede LF and preserves all other
    // bytes, so a semantic or whitespace change still fails closed.
    public static string CanonicalTextHash(string path)
    {
        var bytes = File.ReadAllBytes(path);
        using var canonical = new MemoryStream(bytes.Length);
        for (var index = 0; index < bytes.Length; index++)
        {
            if (bytes[index] == (byte)'\r' && index + 1 < bytes.Length && bytes[index + 1] == (byte)'\n')
                continue;
            canonical.WriteByte(bytes[index]);
        }

        return Convert.ToHexString(SHA256.HashData(canonical.ToArray())).ToLowerInvariant();
    }
}

internal sealed record GatePolicySet(
    IReadOnlyDictionary<string, string[]> ProviderContracts,
    IReadOnlyList<string> SharedPrimitiveProjects,
    IReadOnlyList<PolicyBindingInfo> Bindings,
    WaiverPolicyInfo? WaiverPolicy,
    string CompositeHash
)
{
    public static GatePolicySet Unbound(string configPath) => new(
        new Dictionary<string, string[]>(StringComparer.OrdinalIgnoreCase),
        [],
        [],
        null,
        PolicyBindingLoader.CompositeHash([new PolicyBindingFile("layerguard", configPath)])
    );
}

internal static class PolicyBindingLoader
{
    public const string GatePolicySection = "gatePolicies";

    public static GatePolicySet Load(JsonElement? section, JsonElement config, string configPath)
    {
        if (section is null)
            return GatePolicySet.Unbound(configPath);

        var binding = PolicyBindings.Find(GatePolicySection)
            ?? throw new InvalidDataException(
                $"{configPath} configures `{GatePolicySection}`, but this host registered no policy binding for it."
            );
        var result = binding.Load(section.Value, config, configPath);
        return new GatePolicySet(
            result.ProviderContracts,
            result.SharedPrimitiveProjects,
            result.Bindings,
            result.WaiverPolicy,
            CompositeHash([new PolicyBindingFile("layerguard", configPath), .. result.HashedFiles])
        );
    }

    internal static string CompositeHash(IEnumerable<PolicyBindingFile> files)
    {
        var text = new StringBuilder();
        foreach (var file in files.OrderBy(item => item.Label, StringComparer.Ordinal))
        {
            var normalized = File.ReadAllText(file.Path).Replace("\r\n", "\n", StringComparison.Ordinal).Replace('\r', '\n');
            text.Append(file.Label).Append('\n').Append(normalized).Append('\n');
        }
        return Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(text.ToString()))).ToLowerInvariant();
    }
}
