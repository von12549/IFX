using LayerGuard;
using Xunit;

namespace LayerGuard.Tests;

/// tests/fixtures/ForbiddenDependencies — six endpoint classes in Presentation, one of which
/// asks a use case for its answer and five of which were handed storage. A reference says a
/// layer can see something and an import says a file names it; only a parameter says an
/// instance was passed in.
public class ForbiddenDependencyTests
{
    [Fact]
    public void A_type_handed_nothing_the_rule_names_is_not_reported()
    {
        var report = Fixtures.Check(Fixtures.ForbiddenDependencies);

        Assert.DoesNotContain(
            report.Violations,
            violation => violation.Path.Contains("OrderEndpoints")
        );
    }

    [Fact]
    public void A_primary_constructor_parameter_is_read()
    {
        var violation = Single(Fixtures.Check(Fixtures.ForbiddenDependencies), "UserEndpoints");

        Assert.Equal(InjectionRules.Rule, violation.Rule);
        Assert.Equal("IUserRepository", violation.ToProject);
        Assert.Equal("constructor parameter", violation.Kind);
        Assert.Equal("IUserRepository users", violation.FixAt.Text);
    }

    [Fact]
    public void A_declared_constructor_says_the_same_thing_and_is_read_too()
    {
        var violation = Single(Fixtures.Check(Fixtures.ForbiddenDependencies), "AuditEndpoints");

        Assert.Equal("IAuditRepository", violation.ToProject);
        Assert.Equal("IAuditRepository audit", violation.FixAt.Text);
    }

    [Fact]
    public void Wrapping_the_dependency_does_not_stop_it_being_one()
    {
        var violation = Single(Fixtures.Check(Fixtures.ForbiddenDependencies), "ReportEndpoints");

        // The parameter's own type is IReadOnlyList. The name that matters is written inside it.
        Assert.Equal("IOrderRepository", violation.ToProject);
        Assert.Contains("IReadOnlyList", violation.FixAt.Text);
    }

    [Fact]
    public void A_nullable_dependency_is_still_a_dependency()
    {
        var violation = Single(Fixtures.Check(Fixtures.ForbiddenDependencies), "SearchEndpoints");

        Assert.Equal("ISearchRepository", violation.ToProject);
    }

    [Fact]
    public void A_ring_the_rule_file_says_nothing_about_may_hold_whatever_it_likes()
    {
        var report = Fixtures.Check(Fixtures.ForbiddenDependencies);

        // Acme.Application takes the very type Presentation was refused, and is not judged.
        Assert.DoesNotContain(
            report.Violations,
            violation =>
                violation.FromProject == "Acme.Application" && violation.Rule == InjectionRules.Rule
        );
        Assert.Equal(6, report.ViolationCount);
    }

    [Fact]
    public void A_static_class_is_handed_things_on_its_methods_and_that_is_read_too()
    {
        var violation = Single(Fixtures.Check(Fixtures.ForbiddenDependencies), "TenantEndpoints");

        // TenantEndpoints has no constructor to inject into. A rule reading only constructors
        // would call a whole style of writing this layer clean without looking at it.
        Assert.Equal("method parameter", violation.Kind);
        Assert.Equal("ITenantRepository", violation.ToProject);
    }

    [Fact]
    public void The_report_names_the_family_when_it_runs_and_when_no_rule_asks_for_it()
    {
        Assert.Contains(
            "what a ring may be handed to hold",
            Fixtures.Check(Fixtures.ForbiddenDependencies).Checked
        );

        var silent = Fixtures.Check(Fixtures.CustomRules);
        Assert.Contains(
            silent.NotChecked,
            item => item.StartsWith("what a ring may be handed to hold")
        );
    }

    [Fact]
    public void A_type_is_refused_for_the_ring_that_declared_it_when_no_name_could_say_so()
    {
        var violation = Single(Fixtures.Check(Fixtures.ForbiddenDependencies), "ArchiveOrderHandler");

        // Nothing about the name SqlOrderStore says "concrete class from Infrastructure". Only
        // the ring that declares it does, which is why this rule reads the index and not a
        // pattern.
        Assert.Equal(InjectionRules.OriginRule, violation.Rule);
        Assert.Equal("SqlOrderStore", violation.ToProject);
        Assert.Equal("Infrastructure", violation.ToRing);
        Assert.Equal("Acme.Application", violation.FromProject);
    }

    [Fact]
    public void A_name_the_judged_ring_declares_itself_binds_at_home_and_is_left_alone()
    {
        var report = Fixtures.Check(Fixtures.ForbiddenDependencies);

        // RetryPolicy is declared in Infrastructure and in Application. Names are matched here,
        // never resolved, so the reading that accuses nobody is the one taken.
        Assert.DoesNotContain(
            report.Violations,
            violation => violation.ToProject == "RetryPolicy"
        );
    }

    [Fact]
    public void Building_the_index_is_not_the_same_as_judging_what_a_type_answers_to()
    {
        var report = Fixtures.Check(Fixtures.ForbiddenDependencies);

        // This rule needs the declaration index, but no rule here asks where a contract lives.
        // Saying the contract family ran would be the exact failure this tool exists to prevent.
        Assert.Contains("which ring a type a ring is handed was declared in", report.Checked);
        Assert.DoesNotContain(
            "whether a type answers to a contract declared in another ring",
            report.Checked
        );
        Assert.Contains(
            report.NotChecked,
            item => item.StartsWith("whether a type answers to a contract declared in another ring")
        );
    }

    private static Violation Single(Report report, string type) =>
        report.Violations.Single(violation => violation.Path.Contains(type));
}
