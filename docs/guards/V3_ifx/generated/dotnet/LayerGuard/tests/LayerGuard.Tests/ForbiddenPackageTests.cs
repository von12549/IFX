using LayerGuard;
using Xunit;

namespace LayerGuard.Tests;

/// tests/fixtures/ForbiddenPackages — a Presentation project holding a database library, and a
/// source file importing another one that no project file declares. The rule these prove is the
/// one an allow-list cannot state: a layer that legitimately holds many packages would have to
/// enumerate every one of them to refuse a single kind.
public class ForbiddenPackageTests
{
    [Fact]
    public void A_package_the_layer_may_never_hold_is_reported_from_the_project_file()
    {
        var report = Fixtures.Check(Fixtures.ForbiddenPackages);

        var violation = report.Violations.Single(entry =>
            entry.ToProject == "Microsoft.EntityFrameworkCore"
        );

        Assert.Equal(PackageRules.ForbiddenRule, violation.Rule);
        Assert.Equal("breaks", violation.Severity);
        Assert.Equal("Shop.Presentation", violation.FromProject);
        Assert.Equal("package", violation.Kind);
        Assert.EndsWith("Shop.Presentation.csproj", violation.FixAt.File);
        Assert.Contains("Microsoft.EntityFrameworkCore", violation.FixAt.Text);
    }

    [Fact]
    public void An_import_of_a_forbidden_package_is_reported_even_though_no_project_file_declares_it()
    {
        var report = Fixtures.Check(Fixtures.ForbiddenPackages);

        var violation = report.Violations.Single(entry => entry.ToProject == "Dapper");

        Assert.Equal(PackageRules.ForbiddenRule, violation.Rule);
        Assert.Equal("package import", violation.Kind);
        Assert.EndsWith("OrderEndpoints.cs", violation.FixAt.File);
        Assert.Equal(1, violation.FixAt.Line);
    }

    [Fact]
    public void A_layer_the_rule_file_says_nothing_about_holds_the_same_package_and_is_not_judged()
    {
        var report = Fixtures.Check(Fixtures.ForbiddenPackages);

        Assert.Contains(
            report.Projects,
            project => project.Name == "Shop.Application" && project.Packages == 1
        );
        Assert.DoesNotContain(
            report.Violations,
            violation => violation.FromProject == "Shop.Application"
        );
    }

    [Fact]
    public void A_package_the_layer_is_allowed_and_not_forbidden_stays_silent()
    {
        var report = Fixtures.Check(Fixtures.ForbiddenPackages);

        Assert.DoesNotContain(report.Violations, violation => violation.ToProject == "MediatR");
    }

    [Fact]
    public void The_deny_list_runs_on_its_own_with_no_allow_list_beside_it()
    {
        var report = Fixtures.Check(Fixtures.ForbiddenPackages);

        Assert.Equal(3, report.ViolationCount);
        Assert.All(report.Violations, violation => Assert.Equal(PackageRules.ForbiddenRule, violation.Rule));
        Assert.Contains("which packages a ring may never hold", report.Checked);
        Assert.Contains(report.NotChecked, item => item.StartsWith("which packages a ring may hold"));
    }

    [Fact]
    public void A_rule_file_that_forbids_nothing_says_so_instead_of_passing_quietly()
    {
        var report = Fixtures.Check(Fixtures.CustomRules);

        Assert.DoesNotContain("which packages a ring may never hold", report.Checked);
        Assert.Contains(report.NotChecked, item => item.StartsWith("which packages a ring may never hold"));
    }

    [Fact]
    public void A_package_on_both_lists_is_refused_once_by_the_list_that_names_it()
    {
        var report = Analyzer.Analyze(
            Fixtures.PathTo(Fixtures.ForbiddenPackages),
            Path.Combine(Fixtures.PathTo(Fixtures.ForbiddenPackages), "both-lists.layerguard.json")
        );

        // Npgsql is declared by the project and sits on both lists; Dapper is imported and sits
        // on both. Either way the deny-list wins, and each is reported once rather than once
        // under each rule.
        var declared = report.Violations.Single(violation => violation.ToProject == "Npgsql");
        Assert.Equal(PackageRules.ForbiddenRule, declared.Rule);
        Assert.EndsWith("Shop.Presentation.csproj", declared.FixAt.File);

        var imported = report.Violations.Single(violation => violation.ToProject == "Dapper");
        Assert.Equal(PackageRules.ForbiddenRule, imported.Rule);
        Assert.EndsWith("OrderEndpoints.cs", imported.FixAt.File);

        Assert.Equal(3, report.ViolationCount);
        Assert.DoesNotContain(report.Violations, violation => violation.Rule == PackageRules.Rule);
    }
}
