using LayerGuard;
using Xunit;

namespace LayerGuard.Tests;

/// tests/fixtures/Rulebook — a rule file that states the numbered rules a codebase is audited
/// against, and which of this tool's checks settle each one.
///
/// The mapping is many-to-many: one check serves several numbered rules that differ only by the
/// ring they are about, and one numbered rule is settled by several checks. Worked out by a
/// reader instead of stated here, it comes out differently each time it is worked out.
public class RulebookTests
{
    private static Report Report => Fixtures.Check(Fixtures.Rulebook);

    [Fact]
    public void A_finding_carries_the_numbered_rule_it_answers_to()
    {
        var violation = Report.Violations.Single(entry => entry.ToProject == "Acme.Shared.Legacy"
            && entry.FromRing == "Application");

        Assert.Equal("R-3", violation.Ref);
    }

    [Fact]
    public void The_ring_a_finding_came_from_separates_rules_one_check_serves()
    {
        var report = Report;

        // Three findings, one check, three different numbered rules. Nothing about
        // RING-REFERENCE alone says which of them a finding answers to.
        Assert.Equal(3, report.Violations.Count(v => v.Rule == ReferenceRules.AllowedRule));
        Assert.Equal(
            ["R-1", "R-2", "R-3"],
            report.Violations.Where(v => v.Rule == ReferenceRules.AllowedRule)
                .Select(v => v.Ref).Order()
        );
    }

    [Fact]
    public void A_narrower_entry_claims_a_finding_before_the_one_it_carves_out_of()
    {
        var report = Report;

        // R-1 is Domain-inside-its-own-module; R-2 is Domain anywhere. Both match the first
        // finding, and first match wins, so the order in the rule file is the rule.
        var inModule = report.Violations.Single(v => v.ToProject == "Acme.Billing.Helper");
        var outside = report.Violations.Single(v =>
            v.ToProject == "Acme.Shared.Legacy" && v.FromRing == "Domain");

        Assert.Equal("R-1", inModule.Ref);
        Assert.Equal("R-2", outside.Ref);
    }

    [Fact]
    public void A_finding_no_numbered_rule_claims_carries_none()
    {
        var report = Report;

        var unclaimed = report.Violations.Single(v => v.Rule == PackageRules.Rule);
        Assert.Null(unclaimed.Ref);

        // And it is visible as unclaimed: the rulebook's own counts do not add up to the total.
        Assert.Equal(4, report.ViolationCount);
        Assert.Equal(3, report.Rulebook.Sum(entry => entry.Findings));
    }

    [Theory]
    [InlineData("R-1", "full", 1)]
    [InlineData("R-4", "none", 0)]
    [InlineData("R-5", "partial", 0)]
    public void Coverage_says_what_a_clean_result_would_and_would_not_prove(
        string reference,
        string coverage,
        int findings
    )
    {
        var entry = Report.Rulebook.Single(row => row.Ref == reference);

        Assert.Equal(coverage, entry.Coverage);
        Assert.Equal(findings, entry.Findings);
    }

    [Fact]
    public void A_rule_nothing_settles_and_a_rule_settled_in_part_both_say_what_is_missing()
    {
        var report = Report;

        Assert.Equal("the whole rule", report.Rulebook.Single(r => r.Ref == "R-4").NotMeasured);
        Assert.Equal("a name outside the convention", report.Rulebook.Single(r => r.Ref == "R-5").NotMeasured);

        // A rule measured in full says nothing is missing, which is a different claim from
        // saying nothing about it at all.
        Assert.Null(report.Rulebook.Single(r => r.Ref == "R-1").NotMeasured);
    }

    [Fact]
    public void Every_numbered_rule_appears_whether_or_not_anything_was_found_against_it()
    {
        Assert.Equal(["R-1", "R-2", "R-3", "R-4", "R-5"], Report.Rulebook.Select(r => r.Ref));
        Assert.Contains("every numbered rule of this codebase's own rulebook", Report.Checked);
    }

    [Fact]
    public void A_rule_file_stating_no_rulebook_says_so_rather_than_passing_quietly()
    {
        var report = Fixtures.Check(Fixtures.CustomRules);

        Assert.Empty(report.Rulebook);
        Assert.All(report.Violations, violation => Assert.Null(violation.Ref));
        Assert.Contains(
            report.NotChecked,
            item => item.StartsWith("which numbered rule each finding answers to")
        );
    }

    [Fact]
    public void A_rulebook_naming_a_check_this_tool_does_not_emit_is_refused_at_the_door()
    {
        var config = Path.Combine(Fixtures.PathTo(Fixtures.Rulebook), "bad-rule.layerguard.json");

        var error = Assert.Throws<InvalidDataException>(() =>
            Analyzer.Analyze(Fixtures.PathTo(Fixtures.Rulebook), config)
        );

        // Left through, R-9 would match nothing for ever, and its rule would read as measured
        // by something that never runs.
        Assert.Contains("R-9", error.Message);
        Assert.Contains("RING-TYPO", error.Message);
        Assert.Contains(ReferenceRules.DirectionRule, error.Message);
    }
}
