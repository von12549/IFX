using System.Text.Json;
using static LayerGuard.PolicyDocument;

namespace LayerGuard.Ifx;

/// The IFX policy binding: everything the Architecture Conformance Gate knows about the IFX G03, G04 and G05 review
/// gates lives here rather than in the engine (Plan 06 P6.2 and P6.3, D27). These values are trusted component code,
/// not editable policy, so lowering any of them is a change-trusted-base change; the policy files and the composite
/// policy hash stay byte-identical to what the engine produced before the separation.
public sealed class IfxGatePolicyBinding : IPolicyBinding
{
    public string Section => "gatePolicies";

    private static readonly string[] RequiredUnwaivableCategories =
    [
        "missing-owner", "missing-consumer", "internal-model-exposure",
        "C4-exposure", "unapproved-C3-exposure", "identity-reuse",
    ];

    private static readonly string[] ForbiddenContextDependencies =
    [
        "ASP.NET", "ClaimsPrincipal", "Activity", "dependency injection",
        "serializer", "broker", "Entity Framework", "MediatR",
    ];

    private static readonly (string Id, string Role)[] RequiredDeploymentUnits =
    [
        ("ifx-api", "api"), ("ifx-worker", "worker"), ("ifx-all", "all"),
    ];

    private const string AuthorizedBackupCodeownersHandle = "@jimkeecn";
    private const int MaximumWaiverDays = 90;

    public PolicyBindingResult Load(JsonElement section, JsonElement config, string configPath)
    {
        var g03Reference = RequiredPath(section, "g03Governance", configPath);
        var g04Reference = RequiredPath(section, "g04RuntimeManifest", configPath);
        var g05Reference = RequiredPath(section, "g05ContextPolicy", configPath);
        ValidateGateRoleBinding(config, configPath);

        var g03Path = Resolve(configPath, g03Reference);
        var g04Path = Resolve(configPath, g04Reference);
        var g05Path = Resolve(configPath, g05Reference);
        var hashedFiles = new List<PolicyBindingFile>
        {
            new("G03-governance", g03Path),
            new("G04-runtime", g04Path),
            new("G05-context", g05Path),
        };

        using var g03 = Parse(g03Path, "G03 governance input");
        RequireVersion(g03.RootElement, g03Path);
        var catalogReference = RequiredString(g03.RootElement, "source", g03Path);
        var catalogPath = Resolve(configPath, catalogReference);
        VerifyHash(catalogPath, RequiredString(g03.RootElement, "catalogSha256", g03Path), "G03 catalog");
        hashedFiles.Add(new PolicyBindingFile("G03-catalog", catalogPath));
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
        if (maximumDays <= 0 || maximumDays > MaximumWaiverDays)
            throw new InvalidDataException($"{g03Path} waiverPolicy.maximumDays must be between 1 and {MaximumWaiverDays}.");
        var categories = RequiredArray(waiver, "unwaivable", g03Path)
            .EnumerateArray()
            .Select(item => item.GetString())
            .Where(item => !string.IsNullOrWhiteSpace(item))
            .Select(item => item!)
            .ToArray();
        var missingCategory = RequiredUnwaivableCategories.FirstOrDefault(required =>
            !categories.Contains(required, StringComparer.OrdinalIgnoreCase));
        if (missingCategory is not null)
            throw new InvalidDataException($"{g03Path} waiverPolicy.unwaivable omits `{missingCategory}`.");

        using var g04 = Parse(g04Path, "G04 runtime manifest");
        RequireVersion(g04.RootElement, g04Path);
        ValidateRuntimeRoles(g04.RootElement, g04Path);
        var g04Bindings = VerifyG04Bindings(g04.RootElement, configPath, g04Path);
        hashedFiles.AddRange(g04Bindings.Select(binding => new PolicyBindingFile($"G04-{binding.Name}", binding.Path)));
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
        foreach (var required in ForbiddenContextDependencies)
            if (!forbiddenContext.Contains(required, StringComparer.OrdinalIgnoreCase))
                throw new InvalidDataException($"{g05Path} dependencyPolicy.forbidden omits `{required}`.");

        return new PolicyBindingResult(
            providers,
            sharedProjects,
            [
                new PolicyBindingInfo("G03", g03Path, RawHash(g03Path)),
                new PolicyBindingInfo("G03-catalog", catalogPath, RawHash(catalogPath)),
                new PolicyBindingInfo("G04", g04Path, RawHash(g04Path)),
                .. g04Bindings.Select(binding => new PolicyBindingInfo($"G04-{binding.Name}", binding.Path, binding.Sha256)),
                new PolicyBindingInfo("G05", g05Path, RawHash(g05Path)),
            ],
            new WaiverPolicyInfo(
                maximumDays,
                categories,
                [OwnershipRules.UnknownOwnershipRule, SourcePolicyRules.PayloadRuleId]
            ),
            hashedFiles
        );
    }

    private static string RequiredPath(JsonElement section, string property, string configPath)
    {
        if (!section.TryGetProperty(property, out var value) || value.ValueKind != JsonValueKind.String
            || string.IsNullOrWhiteSpace(value.GetString()))
            throw new InvalidDataException($"{configPath} requires non-empty `gatePolicies.{property}` for 03-A1.");
        return value.GetString()!;
    }

    /// The G04 host artifact is only meaningful when the configuration also binds the composition and host project roles.
    private static void ValidateGateRoleBinding(JsonElement config, string configPath)
    {
        var rings = config.TryGetProperty("rings", out var declaredRings) && declaredRings.ValueKind == JsonValueKind.Object
            ? declaredRings
            : throw new InvalidDataException($"{configPath} must bind the G04 `{Ring.Composition}` project role.");
        foreach (var role in new[] { Ring.Composition.ToString(), Ring.RuntimeHost.ToString() })
            if (!rings.TryGetProperty(role, out _))
                throw new InvalidDataException($"{configPath} must bind the G04 `{role}` project role.");

        var allowed = config.TryGetProperty("allowedDependencies", out var dependencies)
            && dependencies.ValueKind == JsonValueKind.Object
            && dependencies.TryGetProperty(Ring.RuntimeHost.ToString(), out var runtimeHost)
            && runtimeHost.ValueKind == JsonValueKind.Array
                ? runtimeHost.EnumerateArray().Select(item => item.GetString() ?? "").ToArray()
                : [];
        if (allowed.Length != 1 || !allowed[0].Equals(Ring.Composition.ToString(), StringComparison.OrdinalIgnoreCase))
            throw new InvalidDataException($"{configPath} must bind G04 RuntimeHost references to Composition only.");
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
            || !RequiredString(approval, "backupCodeownersHandle", catalogPath).Equals(AuthorizedBackupCodeownersHandle, StringComparison.OrdinalIgnoreCase)
            || !RequiredString(approval, "backupAssignmentStatus", catalogPath).Equals("assigned-and-authorized", StringComparison.OrdinalIgnoreCase))
            throw new InvalidDataException($"{catalogPath} backup owner does not resolve to the authorized record.");

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
                expectedEdges.Add(string.Join("|", identity, kind, consumerModule, providerName));
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
        foreach (var required in RequiredDeploymentUnits.Select(unit => unit.Role))
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
        foreach (var expected in RequiredDeploymentUnits)
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
}
