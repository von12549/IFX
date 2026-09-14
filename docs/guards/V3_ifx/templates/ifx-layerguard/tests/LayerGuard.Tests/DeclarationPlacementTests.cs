using LayerGuard;
using Xunit;

namespace LayerGuard.Tests;

/// tests/fixtures/DeclarationPlacement — four rings, each holding a type the naming convention
/// places somewhere else. This family is what catches a mistake where nothing points the wrong
/// way: every project here references nothing at all, so no direction rule and no import rule
/// has anything to say about any of it.
public class DeclarationPlacementTests
{
    private static Report Report => Fixtures.Check(Fixtures.DeclarationPlacement);

    [Fact]
    public void A_type_declared_where_the_rules_put_it_is_not_reported()
    {
        Assert.DoesNotContain(
            Report.Violations,
            violation => violation.ToProject is "CreateOrderCommandHandler" or "UserRepository"
        );
    }

    [Theory]
    [InlineData("CreateUserCommandHandler", "Domain", "Application")]
    [InlineData("IOrderRepository", "Presentation", "Domain")]
    [InlineData("DeleteOrderQueryHandler", "Presentation", "Application")]
    [InlineData("OrderValidator", "Infrastructure", "Application")]
    public void A_type_declared_in_the_wrong_ring_is_reported_against_the_ring_it_belongs_in(
        string type,
        string declaredIn,
        string belongsIn
    )
    {
        var violation = Report.Violations.Single(entry => entry.ToProject == type);

        Assert.Equal(DeclarationRules.Rule, violation.Rule);
        Assert.Equal(declaredIn, violation.FromRing);
        Assert.Equal(belongsIn, violation.ToRing);
        Assert.Equal("declaration", violation.Kind);
        Assert.Contains(type, violation.FixAt.Text);
    }

    [Fact]
    public void The_kind_filter_is_what_keeps_two_rules_matching_one_name_apart()
    {
        // `I*Repository` sends interfaces to Domain and `*Repository` sends classes to
        // Infrastructure. Both patterns match the name IUserRepository, so without the kind
        // filter the interface sitting correctly in Domain would be reported as belonging in
        // Infrastructure.
        Assert.True(Ruleset.Matches("IUserRepository", "*Repository"));
        Assert.DoesNotContain(Report.Violations, violation => violation.ToProject == "IUserRepository");
    }

    [Fact]
    public void A_rule_that_names_its_own_severity_reports_at_that_level()
    {
        var validator = Report.Violations.Single(entry => entry.ToProject == "OrderValidator");
        var handler = Report.Violations.Single(entry => entry.ToProject == "DeleteOrderQueryHandler");

        Assert.Equal("bends", validator.Severity);
        Assert.Equal("breaks", handler.Severity);
    }

    [Fact]
    public void Nothing_here_points_the_wrong_way_so_no_other_family_would_ever_mention_it()
    {
        var report = Report;

        Assert.All(report.Projects, project => Assert.Equal(0, project.DirectProjectReferences));
        Assert.Equal(4, report.ViolationCount);
        Assert.All(
            report.Violations,
            violation => Assert.Equal(DeclarationRules.Rule, violation.Rule)
        );
    }

    [Fact]
    public void The_fix_names_the_pattern_that_placed_the_type_and_the_project_to_move_it_to()
    {
        var violation = Report.Violations.Single(entry => entry.ToProject == "IOrderRepository");

        Assert.Contains("I*Repository", violation.FixHint);
        Assert.Contains("Domain", violation.FixHint);
    }
}
