using System.Security.Cryptography;
using System.Text;
using System.Text.Json;

namespace LayerGuard;

public sealed record GatePolicyPaths(
    string G03Governance,
    string G04RuntimeManifest,
    string G05ContextPolicy
);

public sealed record PolicyBindingInfo(string Gate, string Source, string Sha256);

public sealed record WaiverPolicyInfo(
    int MaximumDays,
    IReadOnlyList<string> UnwaivableCategories,
    IReadOnlyList<string> UnwaivableRules
);

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
        GatePolicyLoader.CompositeHash([("layerguard", configPath)])
    );
}

internal static class GatePolicyLoader
{
    private static readonly JsonDocumentOptions JsonOptions = new()
    {
        AllowTrailingCommas = true,
        CommentHandling = JsonCommentHandling.Skip,
    };

    public static GatePolicySet Load(GatePolicyPaths? paths, string configPath)
    {
        if (paths is null)
            return GatePolicySet.Unbound(configPath);

        RequirePath(paths.G03Governance, "gatePolicies.g03Governance", configPath);
        RequirePath(paths.G04RuntimeManifest, "gatePolicies.g04RuntimeManifest", configPath);
        RequirePath(paths.G05ContextPolicy, "gatePolicies.g05ContextPolicy", configPath);

        var g03Path = Resolve(configPath, paths.G03Governance);
        var g04Path = Resolve(configPath, paths.G04RuntimeManifest);
        var g05Path = Resolve(configPath, paths.G05ContextPolicy);
        var hashedFiles = new List<(string Label, string Path)>
        {
            ("layerguard", configPath),
            ("G03-governance", g03Path),
            ("G04-runtime", g04Path),
            ("G05-context", g05Path),
        };

        using var g03 = Parse(g03Path, "G03 governance input");
        RequireVersion(g03.RootElement, g03Path);
        var catalogReference = RequiredString(g03.RootElement, "source", g03Path);
        var catalogPath = Resolve(configPath, catalogReference);
        VerifyHash(catalogPath, RequiredString(g03.RootElement, "catalogSha256", g03Path), "G03 catalog");
        hashedFiles.Add(("G03-catalog", catalogPath));
        using var catalog = Parse(catalogPath, "G03 catalog");
        RequireVersion(catalog.RootElement, catalogPath);
        ValidateG03Projection(g03.RootElement, catalog.RootElement, g03Path, catalogPath);

        var ownership = RequiredArray(g03.RootElement, "moduleOwnership", g03Path).EnumerateArray().ToList();
        if (ownership.Count == 0)
            throw new InvalidDataException($"{g03Path} contains no module ownership records.");
        foreach (var entry in ownership)
        {
            var module = RequiredString(entry, "module", g03Path);
            var owner = RequiredString(entry, "owner", g03Path);
            var backup = RequiredString(entry, "backupOwner", g03Path);
            if (owner.Equals(backup, StringComparison.OrdinalIgnoreCase))
                throw new InvalidDataException($"{g03Path} assigns `{module}` the same primary and backup owner.");
        }

        var roles = RequiredObject(g03.RootElement, "contractRoles", g03Path);
        RequireRole(roles, "provider", Ring.Contracts, g03Path);
        RequireRole(roles, "consumerPort", Ring.Application, g03Path);
        RequireRole(roles, "consumerAdapter", Ring.IntegrationAdapter, g03Path);

        var providers = ReadProviderGraph(RequiredObject(g03.RootElement, "providerContracts", g03Path), g03Path);
        ValidateAdapterEdges(RequiredArray(g03.RootElement, "adapterEdges", g03Path), providers, g03Path);

        var sharedProjects = RequiredArray(g03.RootElement, "sharedPrimitiveProjects", g03Path)
            .EnumerateArray()
            .Select(item => item.GetString())
            .Where(item => !string.IsNullOrWhiteSpace(item))
            .Select(item => item!)
            .Distinct(StringComparer.OrdinalIgnoreCase)
            .Order(StringComparer.OrdinalIgnoreCase)
            .ToArray();
        if (sharedProjects.Length == 0)
            throw new InvalidDataException($"{g03Path} contains no shared primitive projects.");
        var contractDependency = RequiredObject(g03.RootElement, "contractDependencyPolicy", g03Path);
        if (!RequiredString(contractDependency, "default", g03Path).Equals("BCL-only", StringComparison.OrdinalIgnoreCase))
            throw new InvalidDataException($"{g03Path} contractDependencyPolicy.default must be `BCL-only`.");

        var waiver = RequiredObject(g03.RootElement, "waiverPolicy", g03Path);
        var maximumDays = RequiredInt(waiver, "maximumDays", g03Path);
        if (maximumDays <= 0 || maximumDays > 90)
            throw new InvalidDataException($"{g03Path} waiverPolicy.maximumDays must be between 1 and 90.");
        var categories = RequiredArray(waiver, "unwaivable", g03Path)
            .EnumerateArray()
            .Select(item => item.GetString())
            .Where(item => !string.IsNullOrWhiteSpace(item))
            .Select(item => item!)
            .ToArray();
        var requiredCategories = new[]
        {
            "missing-owner", "missing-consumer", "internal-model-exposure",
            "C4-exposure", "unapproved-C3-exposure", "identity-reuse",
        };
        var missingCategory = requiredCategories.FirstOrDefault(required =>
            !categories.Contains(required, StringComparer.OrdinalIgnoreCase));
        if (missingCategory is not null)
            throw new InvalidDataException($"{g03Path} waiverPolicy.unwaivable omits `{missingCategory}`.");

        using var g04 = Parse(g04Path, "G04 runtime manifest");
        RequireVersion(g04.RootElement, g04Path);
        ValidateRuntimeRoles(g04.RootElement, g04Path);
        var g04Bindings = VerifyG04Bindings(g04.RootElement, configPath, g04Path);
        hashedFiles.AddRange(g04Bindings.Select(binding => ($"G04-{binding.Name}", binding.Path)));
        ValidateDeploymentUnits(g04.RootElement, g04Bindings, g04Path);

        using var g05 = Parse(g05Path, "G05 context policy");
        RequireVersion(g05.RootElement, g05Path);
        var contextProject = RequiredString(g05.RootElement, "contextProject", g05Path);
        var eventProject = RequiredString(g05.RootElement, "eventProject", g05Path);
        foreach (var project in new[] { contextProject, eventProject })
            if (!sharedProjects.Contains(project, StringComparer.OrdinalIgnoreCase))
                throw new InvalidDataException($"{g05Path} project `{project}` is not admitted by the G03 shared primitive allowlist.");
        var dependencyPolicy = RequiredObject(g05.RootElement, "dependencyPolicy", g05Path);
        if (RequiredArray(dependencyPolicy, "packageReferences", g05Path).GetArrayLength() != 0
            || RequiredArray(dependencyPolicy, "projectReferences", g05Path).GetArrayLength() != 0)
            throw new InvalidDataException($"{g05Path} Context/Messaging Contracts must remain BCL-only.");
        var forbiddenContext = RequiredArray(dependencyPolicy, "forbidden", g05Path)
            .EnumerateArray().Select(item => item.GetString() ?? "").ToArray();
        foreach (var required in new[]
        {
            "ASP.NET", "ClaimsPrincipal", "Activity", "dependency injection",
            "serializer", "broker", "Entity Framework", "MediatR",
        })
            if (!forbiddenContext.Contains(required, StringComparer.OrdinalIgnoreCase))
                throw new InvalidDataException($"{g05Path} dependencyPolicy.forbidden omits `{required}`.");

        return new GatePolicySet(
            providers,
            sharedProjects,
            [
                new("G03", g03Path, RawHash(g03Path)),
                new("G03-catalog", catalogPath, RawHash(catalogPath)),
                new("G04", g04Path, RawHash(g04Path)),
                .. g04Bindings.Select(binding => new PolicyBindingInfo($"G04-{binding.Name}", binding.Path, binding.Sha256)),
                new("G05", g05Path, RawHash(g05Path)),
            ],
            new WaiverPolicyInfo(
                maximumDays,
                categories,
                [OwnershipRules.UnknownOwnershipRule, SourcePolicyRules.PayloadRuleId]
            ),
            CompositeHash(hashedFiles)
        );
    }

    internal static string CompositeHash(IEnumerable<(string Label, string Path)> files)
    {
        var text = new StringBuilder();
        foreach (var (label, path) in files.OrderBy(item => item.Label, StringComparer.Ordinal))
        {
            var normalized = File.ReadAllText(path).Replace("\r\n", "\n", StringComparison.Ordinal).Replace('\r', '\n');
            text.Append(label).Append('\n').Append(normalized).Append('\n');
        }
        return Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(text.ToString()))).ToLowerInvariant();
    }

    private static JsonDocument Parse(string path, string label)
    {
        try { return JsonDocument.Parse(File.ReadAllText(path), JsonOptions); }
        catch (Exception error) { throw new InvalidDataException($"Cannot read {label} `{path}`: {error.Message}", error); }
    }

    private static void RequireVersion(JsonElement root, string path)
    {
        if (!root.TryGetProperty("formatVersion", out var version) || version.GetInt32() != 1)
            throw new InvalidDataException($"{path} requires formatVersion 1.");
    }

    private static IReadOnlyDictionary<string, string[]> ReadProviderGraph(JsonElement element, string path)
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

    private static void ValidateG03Projection(
        JsonElement projection,
        JsonElement catalog,
        string projectionPath,
        string catalogPath
    )
    {
        var owners = RequiredArray(catalog, "owners", catalogPath).EnumerateArray()
            .Select(owner => RequiredString(owner, "id", catalogPath))
            .ToHashSet(StringComparer.OrdinalIgnoreCase);
        var approval = RequiredObject(catalog, "approvalPolicy", catalogPath);
        var authorizedBackup = RequiredString(approval, "backupOwner", catalogPath);
        if (!owners.Contains(authorizedBackup)
            || !RequiredString(approval, "backupCodeownersHandle", catalogPath).Equals("@jimkeecn", StringComparison.OrdinalIgnoreCase)
            || !RequiredString(approval, "backupAssignmentStatus", catalogPath).Equals("assigned-and-authorized", StringComparison.OrdinalIgnoreCase))
            throw new InvalidDataException($"{catalogPath} backup owner does not resolve to the authorized Junxi record.");

        var modules = RequiredArray(catalog, "modules", catalogPath).EnumerateArray().ToList();
        var moduleById = modules.ToDictionary(
            module => RequiredString(module, "id", catalogPath),
            module => RequiredString(module, "name", catalogPath),
            StringComparer.OrdinalIgnoreCase
        );
        var expectedOwnership = modules.Select(module => string.Join("|",
            RequiredString(module, "name", catalogPath),
            RequiredString(module, "owner", catalogPath),
            RequiredString(module, "backupOwner", catalogPath)
        ));
        var actualOwnership = RequiredArray(projection, "moduleOwnership", projectionPath).EnumerateArray()
            .Select(module => string.Join("|",
                RequiredString(module, "module", projectionPath),
                RequiredString(module, "owner", projectionPath),
                RequiredString(module, "backupOwner", projectionPath)
            ));
        RequireSameSet(expectedOwnership, actualOwnership, "module ownership", projectionPath);
        if (modules.Any(module => !RequiredString(module, "backupOwner", catalogPath)
            .Equals(authorizedBackup, StringComparison.OrdinalIgnoreCase)))
            throw new InvalidDataException($"{catalogPath} contains a module not assigned to the authorized backup owner `{authorizedBackup}`.");

        var consumers = RequiredArray(catalog, "consumers", catalogPath).EnumerateArray().ToDictionary(
            consumer => RequiredString(consumer, "id", catalogPath),
            consumer => moduleById[RequiredString(consumer, "module", catalogPath)],
            StringComparer.OrdinalIgnoreCase
        );
        var expectedEdges = new List<string>();
        var expectedProviders = new Dictionary<string, HashSet<string>>(StringComparer.OrdinalIgnoreCase);
        var protocols = RequiredArray(catalog, "protocols", catalogPath).EnumerateArray().ToList();
        if (catalog.TryGetProperty("infrastructureProtocols", out var infrastructureProtocols))
        {
            foreach (var protocol in infrastructureProtocols.EnumerateArray())
            {
                if (RequiredString(protocol, "kind", catalogPath) != "in-process-sensitive"
                    || RequiredString(protocol, "retention", catalogPath) != "request-or-login-transaction"
                    || RequiredString(protocol, "logPolicy", catalogPath) != "never"
                    || !protocol.TryGetProperty("durable", out var durable) || durable.GetBoolean())
                    throw new InvalidDataException($"{catalogPath} sensitive infrastructure protocols require transient in-process use and no logging.");
                protocols.Add(protocol);
            }
        }
        foreach (var protocol in protocols)
        {
            var identity = RequiredString(protocol, "identity", catalogPath);
            var kind = RequiredString(protocol, "kind", catalogPath);
            var providerId = RequiredString(protocol, "provider", catalogPath);
            if (!moduleById.TryGetValue(providerId, out var providerName))
                throw new InvalidDataException($"{catalogPath} protocol `{identity}` names unknown provider `{providerId}`.");
            foreach (var consumerId in RequiredArray(protocol, "consumers", catalogPath).EnumerateArray()
                .Select(item => item.GetString() ?? ""))
            {
                if (!consumers.TryGetValue(consumerId, out var consumerModule))
                    throw new InvalidDataException($"{catalogPath} protocol `{identity}` names unknown consumer `{consumerId}`.");
                expectedEdges.Add(string.Join("|", identity, kind, consumerModule, providerId));
                if (!expectedProviders.TryGetValue(consumerModule, out var providerSet))
                    expectedProviders.Add(consumerModule, providerSet = new(StringComparer.OrdinalIgnoreCase));
                providerSet.Add(providerName);
            }
        }
        var actualEdges = RequiredArray(projection, "adapterEdges", projectionPath).EnumerateArray()
            .Select(edge => string.Join("|",
                RequiredString(edge, "identity", projectionPath),
                RequiredString(edge, "kind", projectionPath),
                RequiredString(edge, "consumer", projectionPath),
                RequiredString(edge, "provider", projectionPath)
            ));
        RequireSameSet(expectedEdges, actualEdges, "adapter edges", projectionPath);

        var actualProviders = ReadProviderGraph(RequiredObject(projection, "providerContracts", projectionPath), projectionPath);
        var expectedProviderRows = expectedProviders.Select(pair =>
            $"{pair.Key}|{string.Join(",", pair.Value.Order(StringComparer.OrdinalIgnoreCase))}");
        var actualProviderRows = actualProviders.Select(pair =>
            $"{pair.Key}|{string.Join(",", pair.Value.Order(StringComparer.OrdinalIgnoreCase))}");
        RequireSameSet(expectedProviderRows, actualProviderRows, "provider graph", projectionPath);

        var expectedShared = RequiredArray(catalog, "sharedPrimitives", catalogPath).EnumerateArray()
            .Select(item => RequiredString(item, "project", catalogPath)).Distinct(StringComparer.OrdinalIgnoreCase);
        var actualShared = RequiredArray(projection, "sharedPrimitiveProjects", projectionPath).EnumerateArray()
            .Select(item => item.GetString() ?? "").Where(item => item.Length > 0);
        RequireSameSet(expectedShared, actualShared, "shared primitive projects", projectionPath);
    }

    private static void RequireSameSet(IEnumerable<string> expected, IEnumerable<string> actual, string label, string path)
    {
        var expectedSet = expected.ToHashSet(StringComparer.OrdinalIgnoreCase);
        var actualSet = actual.ToHashSet(StringComparer.OrdinalIgnoreCase);
        if (!expectedSet.SetEquals(actualSet))
            throw new InvalidDataException(
                $"{path} {label} drifted from the G03 catalog. Missing: [{string.Join(", ", expectedSet.Except(actualSet))}]; "
                + $"unexpected: [{string.Join(", ", actualSet.Except(expectedSet))}]."
            );
    }

    private static void ValidateAdapterEdges(JsonElement edges, IReadOnlyDictionary<string, string[]> providers, string path)
    {
        if (edges.GetArrayLength() == 0)
            throw new InvalidDataException($"{path} contains no adapter edges.");
        foreach (var edge in edges.EnumerateArray())
        {
            var consumer = RequiredString(edge, "consumer", path);
            var provider = RequiredString(edge, "provider", path);
            if (!providers.TryGetValue(consumer, out var admitted)
                || !admitted.Contains(provider, StringComparer.OrdinalIgnoreCase))
                throw new InvalidDataException($"{path} adapter edge `{consumer}` -> `{provider}` is absent from providerContracts.");
        }
    }

    private static void ValidateRuntimeRoles(JsonElement root, string path)
    {
        var host = RequiredObject(root, "hostArtifact", path);
        var roles = RequiredArray(host, "allowedRoles", path)
            .EnumerateArray().Select(item => item.GetString() ?? "").ToArray();
        foreach (var required in new[] { "api", "worker", "all" })
            if (!roles.Contains(required, StringComparer.OrdinalIgnoreCase))
                throw new InvalidDataException($"{path} hostArtifact.allowedRoles omits `{required}`.");
    }

    private sealed record VerifiedBinding(string Name, string Path, string Sha256);

    private static IReadOnlyList<VerifiedBinding> VerifyG04Bindings(JsonElement root, string configPath, string manifestPath)
    {
        var result = new List<VerifiedBinding>();
        foreach (var binding in RequiredObject(root, "bindings", manifestPath).EnumerateObject())
        {
            var reference = RequiredString(binding.Value, "path", manifestPath);
            var path = Resolve(configPath, reference);
            var expected = RequiredString(binding.Value, "sha256", manifestPath);
            VerifyHash(path, expected, $"G04 {binding.Name}");
            result.Add(new VerifiedBinding(binding.Name, path, expected.ToLowerInvariant()));
        }
        if (result.Count == 0)
            throw new InvalidDataException($"{manifestPath} contains no bound artifacts.");
        return result;
    }

    private static void ValidateDeploymentUnits(JsonElement root, IReadOnlyList<VerifiedBinding> bindings, string manifestPath)
    {
        var catalog = bindings.SingleOrDefault(binding => binding.Name.Equals("deploymentUnitCatalog", StringComparison.OrdinalIgnoreCase))
            ?? throw new InvalidDataException($"{manifestPath} does not bind deploymentUnitCatalog.");
        using var document = Parse(catalog.Path, "G04 deployment unit catalog");
        var artifact = RequiredString(RequiredObject(root, "hostArtifact", manifestPath), "artifactId", manifestPath);
        var units = RequiredArray(document.RootElement, "units", catalog.Path).EnumerateArray().ToList();
        foreach (var expected in new[] { (Id: "ifx-api", Role: "api"), (Id: "ifx-worker", Role: "worker"), (Id: "ifx-all", Role: "all") })
        {
            var unit = units.SingleOrDefault(item =>
                RequiredString(item, "unitId", catalog.Path).Equals(expected.Id, StringComparison.OrdinalIgnoreCase));
            if (unit.ValueKind == JsonValueKind.Undefined
                || !RequiredString(unit, "artifact", catalog.Path).Equals(artifact, StringComparison.OrdinalIgnoreCase)
                || !RequiredArray(unit, "configuration", catalog.Path).EnumerateArray()
                    .Select(item => item.GetString()).Contains($"Runtime:Role={expected.Role}", StringComparer.OrdinalIgnoreCase))
                throw new InvalidDataException($"{catalog.Path} does not bind `{expected.Id}` to `{artifact}` with Runtime:Role={expected.Role}.");
        }
    }

    private static void RequireRole(JsonElement roles, string property, Ring expected, string path)
    {
        var value = RequiredString(roles, property, path);
        if (!Enum.TryParse<Ring>(value, true, out var role) || role != expected)
            throw new InvalidDataException($"{path} contractRoles.{property} must be `{expected}`; found `{value}`.");
    }

    private static string RequiredString(JsonElement element, string property, string path)
    {
        if (!element.TryGetProperty(property, out var value) || value.ValueKind != JsonValueKind.String
            || string.IsNullOrWhiteSpace(value.GetString()))
            throw new InvalidDataException($"{path} requires non-empty `{property}`.");
        return value.GetString()!;
    }

    private static int RequiredInt(JsonElement element, string property, string path)
    {
        if (!element.TryGetProperty(property, out var value) || value.ValueKind != JsonValueKind.Number)
            throw new InvalidDataException($"{path} requires numeric `{property}`.");
        return value.GetInt32();
    }

    private static JsonElement RequiredObject(JsonElement element, string property, string path)
    {
        if (!element.TryGetProperty(property, out var value) || value.ValueKind != JsonValueKind.Object)
            throw new InvalidDataException($"{path} requires object `{property}`.");
        return value;
    }

    private static JsonElement RequiredArray(JsonElement element, string property, string path)
    {
        if (!element.TryGetProperty(property, out var value) || value.ValueKind != JsonValueKind.Array)
            throw new InvalidDataException($"{path} requires array `{property}`.");
        return value;
    }

    private static void RequirePath(string? value, string property, string configPath)
    {
        if (string.IsNullOrWhiteSpace(value))
            throw new InvalidDataException($"{configPath} requires non-empty `{property}` for 03-A1.");
    }

    private static string Resolve(string configPath, string reference)
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

    private static void VerifyHash(string path, string expected, string label)
    {
        var actual = RawHash(path);
        if (!actual.Equals(expected, StringComparison.OrdinalIgnoreCase))
            throw new InvalidDataException($"{label} hash mismatch for `{path}`: expected {expected}, actual {actual}.");
    }

    private static string RawHash(string path) =>
        Convert.ToHexString(SHA256.HashData(File.ReadAllBytes(path))).ToLowerInvariant();
}
