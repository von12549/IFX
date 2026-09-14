using LayerGuard;
using Xunit;

namespace LayerGuard.Tests;

/// tests/fixtures/AllowedDirections — every dependency Clean Architecture permits, written out
/// so a change that starts refusing one of them fails a named test instead of quietly making
/// the tool stricter than the rule it claims to enforce.
public class AllowedDirectionTests
{
    [Theory]
    [InlineData("Allowed.Application", "Allowed.Domain")]
    [InlineData("Allowed.Presentation", "Allowed.Application")]
    [InlineData("Allowed.Presentation", "Allowed.Domain")]
    [InlineData("Allowed.Infrastructure", "Allowed.Application")]
    [InlineData("Allowed.Infrastructure", "Allowed.Domain")]
    public void The_allowed_pair_is_silent(string from, string to)
    {
        // The dependency has to be there for silence to mean anything. Without this, deleting
        // every reference in the fixture would leave the assertion below passing.
        var referencing = CsprojReader.Read(Fixtures.ProjectFile(Fixtures.AllowedDirections, from));
        Assert.Contains(
            referencing.ProjectReferences,
            reference => reference.ResolvedPath.EndsWith($"{to}.csproj")
        );

        var report = Fixtures.Check(Fixtures.AllowedDirections);

        Assert.DoesNotContain(
            report.Violations,
            violation => violation.FromProject == from && violation.ToProject == to
        );
    }

    [Fact]
    public void A_codebase_of_only_allowed_dependencies_comes_back_clean()
    {
        var report = Fixtures.Check(Fixtures.AllowedDirections);

        Assert.Equal("clean", report.Verdict);
        Assert.Empty(report.Violations);
        Assert.Equal(4, report.Scope.ProjectsInScope);
    }
}

/// The rule table on its own, without a codebase. Twelve ordered pairs, five allowed and seven
/// refused; the fixtures above drive each of those through the analyzer.
public class RulesetTests
{
    [Theory]
    [InlineData(Ring.Domain, Ring.Application, false)]
    [InlineData(Ring.Domain, Ring.Presentation, false)]
    [InlineData(Ring.Domain, Ring.Infrastructure, false)]
    [InlineData(Ring.Application, Ring.Domain, true)]
    [InlineData(Ring.Application, Ring.Presentation, false)]
    [InlineData(Ring.Application, Ring.Infrastructure, false)]
    [InlineData(Ring.Presentation, Ring.Domain, true)]
    [InlineData(Ring.Presentation, Ring.Application, true)]
    [InlineData(Ring.Presentation, Ring.Infrastructure, false)]
    [InlineData(Ring.Infrastructure, Ring.Domain, true)]
    [InlineData(Ring.Infrastructure, Ring.Application, true)]
    [InlineData(Ring.Infrastructure, Ring.Presentation, false)]
    public void The_direction_table_has_twelve_settled_cells(Ring from, Ring to, bool allowed) =>
        Assert.Equal(allowed, Ruleset.Default.Allows(from, to));

    [Theory]
    [InlineData("Acme.Billing.Domain", Ring.Domain)]
    [InlineData("Acme.Billing.Application", Ring.Application)]
    [InlineData("Acme.Billing.Presentation", Ring.Presentation)]
    [InlineData("Acme.Billing.Infrastructure", Ring.Infrastructure)]
    [InlineData("Acme.Billing.Abstractions", Ring.Outside)]
    [InlineData("Acme.Shared", Ring.Outside)]
    public void A_layer_is_recognised_by_the_project_name(string name, Ring expected) =>
        Assert.Equal(expected, Ruleset.Default.RingOf(name));
}

/// What every report says about itself, whatever it found.
public class ReportTests
{
    [Fact]
    public void The_report_names_what_it_looked_at_and_what_it_did_not()
    {
        var report = Fixtures.Check(Fixtures.DirectReference);

        Assert.Contains("project references", report.Checked);

        // These fixtures are project files with no source beside them, and the built-in rules
        // state nothing about packages. Both facts have to reach the reader by name, or a clean
        // verdict reads as "checked and fine" when it means "never looked".
        Assert.Contains(report.NotChecked, item => item.StartsWith("import directives"));
        Assert.Contains(report.NotChecked, item => item.StartsWith("which packages a ring may hold"));
    }

    [Fact]
    public void The_report_names_the_rules_it_used()
    {
        var report = Fixtures.Check(Fixtures.DirectReference);

        Assert.Equal("built-in default", report.Ruleset.Source);
        Assert.Equal(["Domain"], report.Ruleset.AllowedDependencies["Application"]);
    }

    [Fact]
    public void Findings_are_numbered_in_one_run_so_a_reader_can_cite_them()
    {
        var report = Fixtures.Check(Fixtures.DirectReference);

        Assert.Equal(["V001", "V002", "V003", "V004", "V005", "V006"], report.Violations.Select(v => v.Id));
    }
}
