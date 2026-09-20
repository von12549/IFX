using LayerGuard;
using Xunit;

namespace LayerGuard.Tests;

/// A rulebook that calls one rule a break and another a bend is saying which finding a reader
/// should open first. A tool that reports every finding at one level has thrown that claim away,
/// and a green-looking report is not the only way to mislead someone.
public class SeverityTests
{
    private static Report WithSeverities() =>
        Analyzer.Analyze(
            Fixtures.PathTo(Fixtures.ForbiddenPackages),
            Path.Combine(Fixtures.PathTo(Fixtures.ForbiddenPackages), "both-lists.layerguard.json")
        );

    [Fact]
    public void A_rule_the_file_gives_a_severity_reports_at_that_severity()
    {
        var report = WithSeverities();

        Assert.All(
            report.Violations.Where(violation => violation.Rule == PackageRules.ForbiddenRule),
            violation => Assert.Equal("drift", violation.Severity)
        );
    }

    [Fact]
    public void A_rule_the_file_says_nothing_about_keeps_the_severity_it_carries()
    {
        var report = Fixtures.Check(Fixtures.ForbiddenPackages);

        Assert.All(report.Violations, violation => Assert.Equal("breaks", violation.Severity));
    }

    [Fact]
    public void A_declaration_rule_states_its_own_severity_and_that_is_the_narrower_claim()
    {
        var report = Fixtures.Check(Fixtures.Implements);

        // The entry in `declarations` says bends. Nothing in `severities` overrides an entry
        // that named its own level.
        Assert.All(report.Violations, violation => Assert.Equal("bends", violation.Severity));
    }

    [Fact]
    public void A_severity_nobody_recognises_is_refused_at_the_door()
    {
        var config = Path.Combine(
            Fixtures.PathTo(Fixtures.ForbiddenPackages),
            "bad-severity.layerguard.json"
        );

        var error = Assert.Throws<InvalidDataException>(() =>
            Analyzer.Analyze(Fixtures.PathTo(Fixtures.ForbiddenPackages), config)
        );

        // Left through, it would produce findings that every reader filtering on the three known
        // levels quietly drops — a hole that looks exactly like having no findings.
        Assert.Contains("critical", error.Message);
        Assert.Contains("breaks, bends or drift", error.Message);
    }

    [Fact]
    public void The_structure_rule_keeps_drift_as_the_level_it_carries()
    {
        Assert.Equal("drift", Ruleset.Default.SeverityOf(StructureRules.Rule, Ruleset.Drift));
        Assert.Equal("breaks", Ruleset.Default.SeverityOf(ReferenceRules.DirectionRule));
    }
}
