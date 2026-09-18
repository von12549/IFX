using LayerGuard;
using Xunit;

namespace LayerGuard.Tests;

public class BootstrapConfigurationTests
{
    [Theory]
    [InlineData("{ \"rings\": { \"Mystery\": [\"*\"] } }", "not a project role")]
    [InlineData("{ \"ownership\": { \"modulePatterns\": [\"Acme.*\"] } }", "{module}")]
    [InlineData("{ \"referenceScopes\": [{ \"from\": \"Application\", \"to\": \"Contracts\", \"ownership\": \"sometimes\" }] }", "must be own")]
    [InlineData("{ \"unknownProperty\": true }", "could not be mapped")]
    public void Invalid_configuration_fails_closed(string json, string expected)
    {
        var path = Path.Combine(Path.GetTempPath(), $"layerguard-{Guid.NewGuid():N}.json");
        try
        {
            File.WriteAllText(path, json);
            var error = Assert.ThrowsAny<Exception>(() => Analyzer.Analyze(
                Fixtures.PathTo(Fixtures.AllowedDirections), path));
            Assert.Contains(expected, error.Message, StringComparison.OrdinalIgnoreCase);
        }
        finally
        {
            File.Delete(path);
        }
    }

    [Fact]
    public void Duplicate_reference_scope_is_rejected()
    {
        const string json = """
        { "referenceScopes": [
          { "from": "Application", "to": "Contracts", "ownership": "own" },
          { "from": "Application", "to": "Contracts", "ownership": "own" }
        ] }
        """;
        var path = Path.Combine(Path.GetTempPath(), $"layerguard-{Guid.NewGuid():N}.json");
        try
        {
            File.WriteAllText(path, json);
            var error = Assert.Throws<InvalidDataException>(() => Analyzer.Analyze(
                Fixtures.PathTo(Fixtures.AllowedDirections), path));
            Assert.Contains("duplicate", error.Message, StringComparison.OrdinalIgnoreCase);
        }
        finally
        {
            File.Delete(path);
        }
    }

    [Fact]
    public void Provider_cycles_fail_the_architecture_graph()
    {
        const string json = """
        { "providerContracts": { "Billing": ["Sales"], "Sales": ["Billing"] } }
        """;
        var path = Path.Combine(Path.GetTempPath(), $"layerguard-{Guid.NewGuid():N}.json");
        try
        {
            File.WriteAllText(path, json);
            var report = Analyzer.Analyze(Fixtures.PathTo(Fixtures.AllowedDirections), path);
            Assert.Contains(report.Violations, finding => finding.Rule == OwnershipRules.ProviderCycleRule);
        }
        finally
        {
            File.Delete(path);
        }
    }

    [Fact]
    public void Dependency_graph_contains_project_and_namespace_edges()
    {
        var graph = ArchitectureGraph.Build(Fixtures.PathTo(Fixtures.BootstrapArchitecture), null);
        Assert.Contains(graph.ProjectEdges, edge => edge.From == "Acme.Billing.Application"
            && edge.To == "Acme.Sales.Contracts");
        Assert.Contains(graph.NamespaceEdges, edge => edge.From == "Acme.Billing.Integration"
            && edge.To == "Acme.Sales.Contracts");
    }
}
