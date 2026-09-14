using LayerGuard;
using Xunit;

namespace LayerGuard.Tests;

/// tests/fixtures/Imports — one Domain file with five using directives, each of which the rules
/// have to treat differently. A reference says a layer *can* see something; an import is where
/// somebody walked through the boundary, and Acme.Domain names Acme.Application without
/// referencing it at all.
///
/// The line numbers below are asserted, so the fixture's layout is fixed on purpose.
public class ImportTests
{
    private static Report Report => Fixtures.Check(Fixtures.Imports);

    [Fact]
    public void An_import_of_another_ring_is_refused_even_with_no_reference_behind_it()
    {
        var violation = Report.Violations.Single(entry => entry.Rule == ImportRules.DirectionRule);

        Assert.Equal("Acme.Domain", violation.FromProject);
        Assert.Equal("Acme.Application", violation.ToProject);
        Assert.Equal("import", violation.Kind);
        Assert.Equal(2, violation.FixAt.Line);
        Assert.Equal("using Acme.Application;", violation.FixAt.Text);

        // Nothing in the project file points this way. The direction rule reading project
        // references alone would call Acme.Domain clean.
        Assert.Single(Report.Projects, project => project.Name == "Acme.Domain" && project.DirectProjectReferences == 1);
        Assert.DoesNotContain(
            Report.Violations,
            entry => entry.Rule == ReferenceRules.DirectionRule
        );
    }

    [Fact]
    public void A_namespace_no_project_declares_is_judged_against_the_rings_package_rule()
    {
        var violation = Report.Violations.Single(entry =>
            entry.ToProject == "Microsoft.EntityFrameworkCore"
        );

        Assert.Equal(ImportRules.PackageRule, violation.Rule);
        Assert.Equal("package import", violation.Kind);
        Assert.Equal(3, violation.FixAt.Line);
    }

    [Fact]
    public void An_import_inside_a_branch_the_preprocessor_turned_off_is_reported_and_marked()
    {
        var violation = Report.Violations.Single(entry => entry.ToProject == "Dapper");

        // A disabled branch never enters the syntax tree, so a tree-only walker reports nothing
        // AND says nothing — a silent miss, which is worse than a noisy one. The import is real
        // in whatever configuration turns the branch on.
        Assert.Equal(ImportRules.PackageRule, violation.Rule);
        Assert.Contains("preprocessor had turned off", violation.Kind);
        Assert.Equal(7, violation.FixAt.Line);
        Assert.Equal("using Dapper;", violation.FixAt.Text);
    }

    [Fact]
    public void A_framework_namespace_is_not_a_package_this_codebase_chose()
    {
        Assert.DoesNotContain(Report.Violations, violation => violation.ToProject.StartsWith("System"));
    }

    [Fact]
    public void A_loaded_project_that_matches_no_ring_is_not_judged_as_a_package()
    {
        // Acme.Shared is Outside: listed, never ruled on. Calling its namespace a package would
        // rule on it through the back door, under a rule written for libraries — and Domain's
        // package list here allows nothing at all, so it would certainly be reported.
        var inForce = Ruleset.Load(Fixtures.PathTo(Fixtures.Imports), explicitConfigPath: null);

        Assert.Contains(Report.Outside, project => project.Name == "Acme.Shared");
        Assert.Empty(inForce.PackagesAllowedIn(Ring.Domain)!);
        Assert.DoesNotContain(Report.Violations, violation => violation.ToProject == "Acme.Shared");
    }

    [Fact]
    public void Five_imports_produce_exactly_the_three_findings_they_should()
    {
        Assert.Equal(3, Report.ViolationCount);
        Assert.Contains("import directives in 1 source files", Report.Checked);
    }
}
