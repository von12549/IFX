using LayerGuard;
using Xunit;

namespace LayerGuard.Tests;

/// tests/fixtures/AllowedReferences — three modules and two shared projects, with a rule file
/// saying which projects Domain and Application may name. The direction table rules on pairs of
/// rings and has nothing to say about a project that matches no ring, so "this layer may
/// reference these and nothing else" is not a direction it can refuse.
public class AllowedReferenceTests
{
    [Fact]
    public void A_project_the_list_names_is_referenced_without_complaint()
    {
        var report = Fixtures.Check(Fixtures.AllowedReferences);

        Assert.DoesNotContain(
            report.Violations,
            violation => violation.ToProject == "Acme.Shared.Domain"
        );
    }

    [Fact]
    public void A_project_the_list_does_not_name_is_reported_at_the_line_that_names_it()
    {
        var report = Fixtures.Check(Fixtures.AllowedReferences);

        var violation = report.Violations.Single(entry => entry.Rule == ReferenceRules.AllowedRule);

        Assert.Equal("Acme.Billing.Domain", violation.FromProject);
        Assert.Equal("Acme.Shared.Legacy", violation.ToProject);
        Assert.Equal("breaks", violation.Severity);
        Assert.EndsWith("Acme.Billing.Domain.csproj", violation.FixAt.File);
        Assert.Contains("Acme.Shared.Legacy", violation.FixAt.Text);
    }

    [Fact]
    public void This_is_the_only_rule_that_reaches_a_project_matching_no_layer()
    {
        var report = Fixtures.Check(Fixtures.AllowedReferences);

        var violation = report.Violations.Single(entry => entry.Rule == ReferenceRules.AllowedRule);

        // Acme.Shared.Legacy matches no ring pattern, so it is Outside — listed by the report and
        // never ruled on by the direction table, whichever way the reference points.
        Assert.Equal("Outside", violation.ToRing);
        Assert.Contains(report.Outside, project => project.Name == "Acme.Shared.Legacy");
    }

    [Fact]
    public void A_layer_the_rule_file_says_nothing_about_may_name_whatever_it_likes()
    {
        var report = Fixtures.Check(Fixtures.AllowedReferences);

        // Infrastructure references the same project Domain was refused for, and is not judged:
        // no allow-list was written for it.
        Assert.DoesNotContain(
            report.Violations,
            violation => violation.FromProject == "Acme.Billing.Infrastructure"
        );
    }

    [Fact]
    public void A_reference_both_lists_refuse_is_reported_once_under_the_one_that_names_it()
    {
        var report = Fixtures.Check(Fixtures.AllowedReferences);

        // Acme.Billing.Abstractions is off Application's allow-list and is also forbidden inside
        // the module. The deny-list is read first, because a rule that names the project says
        // more to a reader than a rule that merely fails to mention it.
        var violation = Assert.Single(
            report.Violations,
            entry => entry.ToProject == "Acme.Billing.Abstractions"
        );

        Assert.Equal(ReferenceRules.ForbiddenRule, violation.Rule);
        Assert.Equal("reference inside the module", violation.Kind);
    }

    [Fact]
    public void An_edge_the_direction_table_already_refuses_is_not_reported_a_second_time()
    {
        var report = Fixtures.Check(Fixtures.AllowedReferences);

        var forOrder = report
            .Violations.Where(violation => violation.FromProject == "Acme.Order.Domain")
            .ToList();

        // Acme.Order.Infrastructure is off Domain's allow-list and is also a direction Domain may
        // not point in. One mistake, one finding, under the rule that describes it best.
        var violation = Assert.Single(forOrder);
        Assert.Equal(ReferenceRules.DirectionRule, violation.Rule);
    }

    [Fact]
    public void The_report_names_the_family_when_it_runs_and_when_it_does_not()
    {
        Assert.Contains("which projects a ring may name", Fixtures.Check(Fixtures.AllowedReferences).Checked);

        var silent = Fixtures.Check(Fixtures.CustomRules);
        Assert.DoesNotContain("which projects a ring may name", silent.Checked);
        Assert.Contains(silent.NotChecked, item => item.StartsWith("which projects a ring may name"));
    }

    [Fact]
    public void The_whole_fixture_produces_exactly_the_three_findings_it_was_built_to_produce()
    {
        var report = Fixtures.Check(Fixtures.AllowedReferences);

        Assert.Equal(
            [ReferenceRules.ForbiddenRule, ReferenceRules.AllowedRule, ReferenceRules.DirectionRule],
            report.Violations.Select(violation => violation.Rule)
        );
    }
}
