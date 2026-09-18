using System.Text.Json;
using LayerGuard;
using Xunit;

namespace LayerGuard.Tests;

/// The engine carries no repository policy of its own: a configuration that binds a section is only analyzed when a host
/// registered a binding for it, and the binding decides what that section means (Plan 06 P6.3, D27).
public class PolicyBindingTests
{
    [Fact]
    public void Bound_section_without_a_registered_binding_fails_closed()
    {
        var directory = NewDirectory();
        try
        {
            var config = Path.Combine(directory, "layerguard.json");
            File.WriteAllText(config, """
                {
                  "gatePolicies": { "governance": "governance.json" },
                  "rings": { "Domain": ["Acme.*.Domain"] }
                }
                """);

            var error = Assert.Throws<InvalidDataException>(() => Analyzer.Analyze(Fixtures.PathTo(Fixtures.AllowedDirections), config));

            Assert.Contains("registered no policy binding", error.Message);
        }
        finally { Directory.Delete(directory, recursive: true); }
    }

    [Fact]
    public void Registered_binding_supplies_the_provider_graph_waivers_and_composite_hash()
    {
        var directory = NewDirectory();
        try
        {
            var bound = Path.Combine(directory, "bound.json");
            File.WriteAllText(bound, "{ \"formatVersion\": 1 }");
            var config = Path.Combine(directory, "layerguard.json");
            File.WriteAllText(config, """
                {
                  "gatePolicies": { "bound": "bound.json" },
                  "rings": { "Domain": ["Acme.*.Domain"] }
                }
                """);
            PolicyBindings.Register(new StubBinding(bound));

            var report = Analyzer.Analyze(Fixtures.PathTo(Fixtures.AllowedDirections), config);

            Assert.Contains(report.Ruleset.PolicyBindings, binding => binding.Gate == "Stub" && binding.Source == bound);
            Assert.Equal(7, report.Ruleset.WaiverPolicy!.MaximumDays);
            Assert.Equal(64, report.Ruleset.Hash.Length);
            Assert.NotEqual(Ruleset.Default.PolicyHash, report.Ruleset.Hash);
        }
        finally
        {
            PolicyBindings.Register(new UnboundBinding());
            Directory.Delete(directory, recursive: true);
        }
    }

    private static string NewDirectory()
    {
        var directory = Path.Combine(Path.GetTempPath(), $"layerguard-binding-{Guid.NewGuid():N}");
        Directory.CreateDirectory(directory);
        return directory;
    }

    private sealed class StubBinding(string boundPath) : IPolicyBinding
    {
        public string Section => "gatePolicies";

        public PolicyBindingResult Load(JsonElement section, JsonElement config, string configPath)
        {
            var reference = PolicyDocument.RequiredString(section, "bound", configPath);
            var path = PolicyDocument.Resolve(configPath, reference);
            Assert.Equal(boundPath, path);
            using var document = PolicyDocument.Parse(path, "bound artifact");
            PolicyDocument.RequireVersion(document.RootElement, path);
            return new PolicyBindingResult(
                new Dictionary<string, string[]>(StringComparer.OrdinalIgnoreCase) { ["Consumer"] = ["Provider"] },
                ["Acme.Shared.Contracts"],
                [new PolicyBindingInfo("Stub", path, PolicyDocument.RawHash(path))],
                new WaiverPolicyInfo(7, ["unwaivable-category"], []),
                [new PolicyBindingFile("stub", path)]
            );
        }
    }

    /// Restores the default for other tests: a binding that refuses every section it is handed.
    private sealed class UnboundBinding : IPolicyBinding
    {
        public string Section => "gatePolicies";

        public PolicyBindingResult Load(JsonElement section, JsonElement config, string configPath) =>
            throw new InvalidDataException($"{configPath} configures `gatePolicies`, but this host registered no policy binding for it.");
    }
}
