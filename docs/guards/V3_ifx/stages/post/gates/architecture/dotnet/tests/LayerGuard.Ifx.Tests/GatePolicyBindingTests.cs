using System.Text;
using System.Text.Json;
using System.Text.Json.Nodes;
using LayerGuard;
using LayerGuard.Ifx;
using Xunit;

namespace LayerGuard.Ifx.Tests;

public class GatePolicyBindingTests
{
    // The runner passes the package root; otherwise it is the nearest directory above the fixtures that holds the policy,
    // so the tests do not depend on where the source tree sits inside the package (Plan 06 P6.1).
    private static readonly string PackageRoot = ResolvePackageRoot();
    private static readonly string PolicyRoot = ResolvePolicyRoot();
    // A trusted base run executes these tests from a package copy outside the target repository (Plan 06 §11.1).
    private static readonly string RepositoryRoot = Path.GetFullPath(
        Environment.GetEnvironmentVariable("GUARD_TARGET_ROOT") is { Length: > 0 } target
            ? target
            : Path.Combine(PackageRoot, "..", "..", "..")
    );
    private static readonly string G03 = Package("policy/g03/governance.json");
    private static readonly string G04 = Package("policy/g04/runtime-manifest.json");
    private static readonly string G05 = Package("policy/g05/context-protocol-v1.json");

    [Fact]
    public void Production_policy_directly_binds_all_gate_artifacts()
    {
        var report = IfxArchitectureConformance.Analyze(Repo("src"), Package("policy/layerguard.json"));

        Assert.Equal("0.4.0-a1", report.ToolVersion);
        Assert.Contains(report.Ruleset.PolicyBindings, binding => binding.Gate == "G03-catalog");
        Assert.Contains(report.Ruleset.PolicyBindings, binding => binding.Gate == "G04-deploymentUnitCatalog");
        Assert.Contains(report.Ruleset.PolicyBindings, binding => binding.Gate == "G05");
        Assert.Equal(90, report.Ruleset.WaiverPolicy!.MaximumDays);
        Assert.Equal(64, report.Ruleset.Hash.Length);
    }

    [Fact]
    public void Tampered_g03_catalog_hash_fails_closed()
    {
        WithPolicyCopy((directory, g03, g04, g05) =>
        {
            var document = JsonNode.Parse(File.ReadAllText(g03))!.AsObject();
            document["catalogSha256"] = new string('0', 64);
            File.WriteAllText(g03, document.ToJsonString(new JsonSerializerOptions { WriteIndented = true }));

            var error = Assert.Throws<InvalidDataException>(() => Analyze(directory, g03, g04, g05));
            Assert.Contains("G03 catalog hash mismatch", error.Message);
        });
    }

    [Fact]
    public void Unknown_g03_contract_role_fails_closed()
    {
        WithPolicyCopy((directory, g03, g04, g05) =>
        {
            var document = JsonNode.Parse(File.ReadAllText(g03))!.AsObject();
            document["contractRoles"]!["provider"] = "Mystery";
            File.WriteAllText(g03, document.ToJsonString(new JsonSerializerOptions { WriteIndented = true }));

            var error = Assert.Throws<InvalidDataException>(() => Analyze(directory, g03, g04, g05));
            Assert.Contains("contractRoles.provider", error.Message);
        });
    }

    [Fact]
    public void Tampered_g03_provider_projection_fails_closed()
    {
        WithPolicyCopy((directory, g03, g04, g05) =>
        {
            var document = JsonNode.Parse(File.ReadAllText(g03))!.AsObject();
            document["providerContracts"]!["Transaction"]!.AsArray().RemoveAt(0);
            File.WriteAllText(g03, document.ToJsonString(new JsonSerializerOptions { WriteIndented = true }));

            var error = Assert.Throws<InvalidDataException>(() => Analyze(directory, g03, g04, g05));
            Assert.Contains("provider graph drifted", error.Message);
        });
    }

    [Fact]
    public void Sensitive_infrastructure_protocol_cannot_be_made_durable_even_with_matching_hash()
    {
        WithPolicyCopy((directory, g03, g04, g05) =>
        {
            var catalog = JsonNode.Parse(File.ReadAllText(Package("policy/g03/catalog.json")))!.AsObject();
            catalog["infrastructureProtocols"]![0]!["durable"] = true;
            var catalogPath = Path.Combine(directory, "sensitive-catalog.json");
            File.WriteAllText(catalogPath, catalog.ToJsonString());
            var projection = JsonNode.Parse(File.ReadAllText(g03))!.AsObject();
            projection["source"] = catalogPath;
            projection["catalogSha256"] = Convert.ToHexString(System.Security.Cryptography.SHA256.HashData(File.ReadAllBytes(catalogPath))).ToLowerInvariant();
            File.WriteAllText(g03, projection.ToJsonString());
            var error = Assert.Throws<InvalidDataException>(() => Analyze(directory, g03, g04, g05));
            Assert.Contains("sensitive infrastructure protocols", error.Message);
        });
    }

    [Fact]
    public void Tampered_g04_bound_artifact_hash_fails_closed()
    {
        WithPolicyCopy((directory, g03, g04, g05) =>
        {
            var document = JsonNode.Parse(File.ReadAllText(g04))!.AsObject();
            document["bindings"]!["deploymentUnitCatalog"]!["sha256"] = new string('0', 64);
            File.WriteAllText(g04, document.ToJsonString(new JsonSerializerOptions { WriteIndented = true }));

            var error = Assert.Throws<InvalidDataException>(() => Analyze(directory, g03, g04, g05));
            Assert.Contains("G04 deploymentUnitCatalog hash mismatch", error.Message);
        });
    }

    [Fact]
    public void G04_text_binding_accepts_checkout_line_ending_conversion()
    {
        WithPolicyCopy((directory, g03, g04, g05) =>
        {
            var document = JsonNode.Parse(File.ReadAllText(g04))!.AsObject();
            var binding = document["bindings"]!["moduleManifest"]!;
            var sourcePath = binding["path"]!.GetValue<string>();
            var crlfPath = Path.Combine(directory, "module-manifest-crlf.json");
            var canonicalText = File.ReadAllText(sourcePath)
                .Replace("\r\n", "\n", StringComparison.Ordinal)
                .Replace('\r', '\n');
            File.WriteAllText(crlfPath, canonicalText.Replace("\n", "\r\n", StringComparison.Ordinal),
                new UTF8Encoding(encoderShouldEmitUTF8Identifier: false));
            binding["path"] = crlfPath;
            File.WriteAllText(g04, document.ToJsonString(new JsonSerializerOptions { WriteIndented = true }));

            var report = Analyze(directory, g03, g04, g05);

            Assert.Contains(report.Ruleset.PolicyBindings,
                item => item.Gate == "G04-moduleManifest" && item.Source == crlfPath);
        });
    }

    [Fact]
    public void G05_contract_projects_must_remain_bcl_only()
    {
        WithPolicyCopy((directory, g03, g04, g05) =>
        {
            var document = JsonNode.Parse(File.ReadAllText(g05))!.AsObject();
            document["dependencyPolicy"]!["projectReferences"]!.AsArray().Add("Forbidden.Project");
            File.WriteAllText(g05, document.ToJsonString(new JsonSerializerOptions { WriteIndented = true }));

            var error = Assert.Throws<InvalidDataException>(() => Analyze(directory, g03, g04, g05));
            Assert.Contains("BCL-only", error.Message);
        });
    }

    [Fact]
    public void Bound_shared_context_primitives_are_allowed_without_becoming_provider_edges()
    {
        var report = IfxArchitectureConformance.Analyze(Repo("src"), Package("policy/layerguard.json"));

        Assert.DoesNotContain(report.Violations, violation =>
            violation.ToProject == "IFX.Platform.Context.Contracts" &&
            violation.Rule is OwnershipRules.ScopeRule or EmbeddedAdapterRules.ProviderRule);
    }

    [Fact]
    public void Bound_waiver_policy_rejects_overlong_and_unwaivable_entries()
    {
        var report = IfxArchitectureConformance.Analyze(Repo("src"), Package("policy/layerguard.json"));
        var overlong = DateOnly.FromDateTime(DateTime.UtcNow).AddDays(91);
        var expiryError = Assert.Throws<InvalidDataException>(() => Baseline.Snapshot(
            report, "owner", "reason", overlong, "remove after migration"));
        Assert.Contains("maximum of 90 days", expiryError.Message);

        var evidence = new SourceSpan("fixture.csproj", 1, "<Project />");
        var unwaivableFinding = new Violation(
            "TEST",
            OwnershipRules.UnknownOwnershipRule,
            "breaks",
            "Unknown ownership is not waivable",
            "IFX.Modules.Consumer.Application",
            "Application",
            "Consumer",
            "IFX.Modules.Unknown.Contracts",
            "Contracts",
            null,
            "direct project reference",
            ["IFX.Modules.Consumer.Application", "IFX.Modules.Unknown.Contracts"],
            evidence,
            evidence,
            "Register ownership in the authoritative catalog.");
        var unwaivableReport = report with { Violations = [unwaivableFinding], ViolationCount = 1 };
        var waiverError = Assert.Throws<InvalidDataException>(() => Baseline.Snapshot(
            unwaivableReport,
            "owner",
            "reason",
            DateOnly.FromDateTime(DateTime.UtcNow).AddDays(30),
            "remove after migration"
        ));
        Assert.Contains("unwaivable", waiverError.Message);
    }

    private static Report Analyze(string directory, string g03, string g04, string g05)
    {
        var config = Path.Combine(directory, "layerguard.json");
        File.WriteAllText(config, JsonSerializer.Serialize(new
        {
            rings = new Dictionary<string, string[]>
            {
                ["Composition"] = ["IFX.*.Composition"],
                ["RuntimeHost"] = ["IFX.ApiHost"],
            },
            allowedDependencies = new Dictionary<string, string[]>
            {
                ["RuntimeHost"] = ["Composition"],
            },
            gatePolicies = new
            {
                g03Governance = g03,
                g04RuntimeManifest = g04,
                g05ContextPolicy = g05,
            },
        }));
        return IfxArchitectureConformance.Analyze(FixturePath("IfxBinding"), config);
    }

    private static void WithPolicyCopy(Action<string, string, string, string> action)
    {
        var directory = Path.Combine(Path.GetTempPath(), $"layerguard-gates-{Guid.NewGuid():N}");
        Directory.CreateDirectory(directory);
        var g03 = Path.Combine(directory, "g03.json");
        var g04 = Path.Combine(directory, "g04.json");
        var g05 = Path.Combine(directory, "g05.json");
        try
        {
            File.Copy(G03, g03);
            File.Copy(G04, g04);
            File.Copy(G05, g05);
            var g03Document = JsonNode.Parse(File.ReadAllText(g03))!.AsObject();
            g03Document["source"] = Package("policy/g03/catalog.json");
            File.WriteAllText(g03, g03Document.ToJsonString(new JsonSerializerOptions { WriteIndented = true }));

            var g04Document = JsonNode.Parse(File.ReadAllText(g04))!.AsObject();
            foreach (var binding in g04Document["bindings"]!.AsObject())
            {
                var relative = binding.Value!["path"]!.GetValue<string>();
                binding.Value!["path"] = Package("policy/" + relative);
            }
            File.WriteAllText(g04, g04Document.ToJsonString(new JsonSerializerOptions { WriteIndented = true }));
            action(directory, g03, g04, g05);
        }
        finally
        {
            Directory.Delete(directory, recursive: true);
        }
    }

    private static string Repo(string path) => Path.Combine(RepositoryRoot, path.Replace('/', Path.DirectorySeparatorChar));
    private static string ResolvePackageRoot()
    {
        if (Environment.GetEnvironmentVariable("LAYERGUARD_PACKAGE_ROOT") is { Length: > 0 } configured)
            return Path.GetFullPath(configured);
        for (var directory = new DirectoryInfo(FixturePath("IfxBinding")); directory is not null; directory = directory.Parent)
        {
            if (File.Exists(Path.Combine(directory.FullName, "policy", "layerguard.json")) ||
                File.Exists(Path.Combine(directory.FullName, "stages", "post", "policy", "layerguard.json")))
                return directory.FullName;
        }
        throw new InvalidOperationException("Cannot find a legacy or stage-owned policy root above the LayerGuard fixtures.");
    }

    private static string ResolvePolicyRoot()
    {
        var candidates = new[]
        {
            Path.Combine(PackageRoot, "policy"),
            Path.Combine(PackageRoot, "stages", "post", "policy")
        }.Where(path => File.Exists(Path.Combine(path, "layerguard.json"))).ToArray();
        if (candidates.Length != 1)
            throw new InvalidOperationException($"Exactly one complete legacy or stage-owned policy layout must exist; found {candidates.Length}.");
        return candidates[0];
    }

    // The IFX binding tests own their fixtures in this package (Plan 06 P6.4, D29); the runner passes their root.
    private static string FixturePath(string fixture) => Path.Combine(Path.GetFullPath(
        Environment.GetEnvironmentVariable("LAYERGUARD_IFX_FIXTURES_ROOT") is { Length: > 0 } configured
            ? configured
            : Path.Combine(AppContext.BaseDirectory, "..", "..", "..", "..", "fixtures")), fixture);

    private static string Package(string path) => path.StartsWith("policy/", StringComparison.Ordinal)
        ? Path.Combine(PolicyRoot, path["policy/".Length..].Replace('/', Path.DirectorySeparatorChar))
        : Path.Combine(PackageRoot, path.Replace('/', Path.DirectorySeparatorChar));
}
