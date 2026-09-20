using LayerGuard;
using Xunit;

namespace LayerGuard.Tests;

/// tests/fixtures/Implements — four repository classes in Infrastructure and the contracts two
/// of them answer to in Domain. This is the one rule that has to look outside the file in front
/// of it: whether a base type is declared in Domain cannot be read off the class that names it.
public class ImplementsTests
{
    [Fact]
    public void A_class_naming_a_contract_the_required_ring_declares_is_not_reported()
    {
        var report = Fixtures.Check(Fixtures.Implements);

        Assert.DoesNotContain(report.Violations, violation => violation.ToProject == "UserRepository");
    }

    [Fact]
    public void The_contract_may_be_written_out_in_full_and_may_close_a_type_argument()
    {
        var report = Fixtures.Check(Fixtures.Implements);

        // OrderRepository names `Acme.Domain.IOrderRepository<string>`, which Domain declares as
        // `IOrderRepository<T>`. Nothing resolves that to a symbol; the simple name is the match.
        Assert.DoesNotContain(report.Violations, violation => violation.ToProject == "OrderRepository");
    }

    [Fact]
    public void A_class_naming_no_base_type_at_all_answers_to_nothing_and_is_reported()
    {
        var report = Fixtures.Check(Fixtures.Implements);

        var violation = report.Violations.Single(entry => entry.ToProject == "AuditRepository");

        Assert.Equal(DeclarationRules.ImplementsRule, violation.Rule);
        Assert.Equal("Acme.Infrastructure", violation.FromProject);
        Assert.Equal("Domain", violation.ToRing);
        Assert.EndsWith("AuditRepository.cs", violation.FixAt.File);
        Assert.Equal("class AuditRepository", violation.FixAt.Text);
    }

    [Fact]
    public void A_contract_declared_in_the_wrong_ring_does_not_satisfy_the_rule()
    {
        var report = Fixtures.Check(Fixtures.Implements);

        // CacheRepository does implement an interface. ICacheRepository is declared beside it in
        // Infrastructure, so the contract never left the ring that was supposed to answer to it.
        var violation = report.Violations.Single(entry => entry.ToProject == "CacheRepository");

        Assert.Equal(DeclarationRules.ImplementsRule, violation.Rule);
        Assert.Contains("ICacheRepository", violation.FixAt.Text);
    }

    [Fact]
    public void The_severity_the_rule_file_gives_the_rule_is_the_severity_reported()
    {
        var report = Fixtures.Check(Fixtures.Implements);

        Assert.All(report.Violations, violation => Assert.Equal("bends", violation.Severity));
    }

    [Fact]
    public void The_index_places_a_name_under_every_ring_that_declares_it()
    {
        var report = Fixtures.Check(Fixtures.Implements);

        // Two findings and no more: the interfaces in Domain are interfaces, and the rule asks
        // about classes.
        Assert.Equal(2, report.ViolationCount);
        Assert.DoesNotContain(report.Violations, violation => violation.FromRing == "Domain");
    }

    [Fact]
    public void The_report_names_the_family_when_it_runs_and_when_no_rule_asks_for_it()
    {
        Assert.Contains(
            "whether a type answers to a contract declared in another ring",
            Fixtures.Check(Fixtures.Implements).Checked
        );

        var silent = Fixtures.Check(Fixtures.CustomRules);
        Assert.Contains(
            silent.NotChecked,
            item => item.StartsWith("whether a type answers to a contract declared in another ring")
        );
    }
}
