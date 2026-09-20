using LayerGuard;
using Xunit;

namespace LayerGuard.Tests;

/// tests/fixtures/CustomRules — a codebase that names its layers Core, UseCases, Api and
/// Persistence, with a layerguard.json beside it saying so. The built-in rules recognise none
/// of these names, so every assertion here also proves the file was found and used.
public class CustomRulesTests
{
    [Fact]
    public void The_built_in_rules_would_not_recognise_any_of_these_projects()
    {
        Assert.Equal(Ring.Outside, Ruleset.Default.RingOf("Shop.Core"));
        Assert.Equal(Ring.Outside, Ruleset.Default.RingOf("Shop.UseCases"));
        Assert.Equal(Ring.Outside, Ruleset.Default.RingOf("Shop.Api"));
        Assert.Equal(Ring.Outside, Ruleset.Default.RingOf("Shop.Persistence"));
    }

    [Fact]
    public void The_config_sitting_beside_the_code_is_found_and_named_in_the_report()
    {
        var report = Fixtures.Check(Fixtures.CustomRules);

        Assert.EndsWith("layerguard.json", report.Ruleset.Source);
    }

    [Theory]
    [InlineData("Shop.Core", "Domain")]
    [InlineData("Shop.UseCases", "Application")]
    [InlineData("Shop.Api", "Presentation")]
    [InlineData("Shop.Persistence", "Infrastructure")]
    public void A_layer_is_recognised_by_the_name_this_codebase_gives_it(string project, string layer)
    {
        var report = Fixtures.Check(Fixtures.CustomRules);

        Assert.Equal(layer, report.Projects.Single(entry => entry.Name == project).Ring);
    }

    [Fact]
    public void A_pair_the_built_in_rules_allow_is_refused_when_the_config_says_so()
    {
        var report = Fixtures.Check(Fixtures.CustomRules);
        var violation = Assert.Single(report.Violations);

        Assert.True(Ruleset.Default.Allows(Ring.Presentation, Ring.Domain));
        Assert.Equal("Presentation", violation.FromRing);
        Assert.Equal("Domain", violation.ToRing);
        Assert.Equal(["Shop.Api", "Shop.Core"], violation.Path);
    }

    [Fact]
    public void The_pairs_the_config_still_allows_stay_silent()
    {
        var report = Fixtures.Check(Fixtures.CustomRules);

        Assert.DoesNotContain(report.Violations, violation => violation.FromProject == "Shop.UseCases");
        Assert.DoesNotContain(report.Violations, violation => violation.FromProject == "Shop.Persistence");
    }

    [Fact]
    public void An_explicit_config_path_beats_the_search()
    {
        var report = Analyzer.Analyze(
            Fixtures.PathTo(Fixtures.DirectReference),
            Path.Combine(Fixtures.PathTo(Fixtures.CustomRules), "layerguard.json")
        );

        Assert.EndsWith("layerguard.json", report.Ruleset.Source);
        Assert.Empty(report.Violations);
        Assert.Equal(4, report.Scope.ProjectsOutside);
    }
}
