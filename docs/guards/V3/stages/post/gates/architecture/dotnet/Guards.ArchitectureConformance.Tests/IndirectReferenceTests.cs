using LayerGuard;
using Xunit;

namespace LayerGuard.Tests;

/// tests/fixtures/IndirectReference — the same refused pairs as DirectReference, except no
/// layer names the layer it must not see. Each one goes through a carrier project that matches
/// no layer, which is how a boundary disappears without anyone writing it down.
public class IndirectReferenceTests
{
    [Theory]
    [InlineData("Domain", "Application", "Indirect.AppCarrier")]
    [InlineData("Domain", "Presentation", "Indirect.PresCarrier")]
    [InlineData("Domain", "Infrastructure", "Indirect.InfraCarrier")]
    [InlineData("Application", "Presentation", "Indirect.PresCarrier")]
    [InlineData("Application", "Infrastructure", "Indirect.InfraCarrier")]
    [InlineData("Presentation", "Infrastructure", "Indirect.InfraCarrier")]
    public void The_refused_pair_is_reported_with_the_whole_chain(string from, string to, string carrier)
    {
        var violation = Fixtures.Check(Fixtures.IndirectReference).Between(from, to);

        Assert.Equal("transitive", violation.Kind);
        Assert.Equal([$"Indirect.{from}", carrier, $"Indirect.{to}"], violation.Path);
    }

    [Theory]
    [InlineData("Domain", "Application", "Indirect.AppCarrier")]
    [InlineData("Domain", "Presentation", "Indirect.PresCarrier")]
    [InlineData("Domain", "Infrastructure", "Indirect.InfraCarrier")]
    [InlineData("Application", "Presentation", "Indirect.PresCarrier")]
    [InlineData("Application", "Infrastructure", "Indirect.InfraCarrier")]
    [InlineData("Presentation", "Infrastructure", "Indirect.InfraCarrier")]
    public void The_fix_is_the_carrier_not_the_layer_that_reported_it(string from, string to, string carrier)
    {
        var violation = Fixtures.Check(Fixtures.IndirectReference).Between(from, to);

        Assert.EndsWith($"Indirect.{from}.csproj", violation.Evidence.File);
        Assert.EndsWith($"{carrier}.csproj", violation.FixAt.File);
        Assert.Contains("Close the last hop", violation.FixHint);
    }

    [Fact]
    public void The_fixture_holds_six_refused_pairs_and_nothing_else()
    {
        var report = Fixtures.Check(Fixtures.IndirectReference);

        Assert.Equal(6, report.ViolationCount);
        Assert.All(report.Violations, violation => Assert.Equal("transitive", violation.Kind));
    }

    [Fact]
    public void The_carriers_are_listed_and_never_ruled_on()
    {
        var report = Fixtures.Check(Fixtures.IndirectReference);

        Assert.Equal(
            ["Indirect.AppCarrier", "Indirect.InfraCarrier", "Indirect.PresCarrier"],
            report.Outside.Select(project => project.Name).Order().ToArray()
        );
        Assert.DoesNotContain(report.Violations, violation => violation.ToProject.EndsWith("Carrier"));
    }
}

/// tests/fixtures/IndirectSiblingReference — the seventh refused pair, reached through a carrier.
public class IndirectSiblingReferenceTests
{
    [Fact]
    public void Infrastructure_may_not_reach_Presentation_through_another_project()
    {
        var report = Fixtures.Check(Fixtures.IndirectSiblingReference);
        var violation = Assert.Single(report.Violations);

        Assert.Equal("transitive", violation.Kind);
        Assert.Equal(
            ["IndSibling.Infrastructure", "IndSibling.PresCarrier", "IndSibling.Presentation"],
            violation.Path
        );
        Assert.EndsWith("IndSibling.PresCarrier.csproj", violation.FixAt.File);
    }
}

/// tests/fixtures/IndirectKeptPrivate — the same seven projects as IndirectReference, with one
/// difference: every carrier marks its own reference private, so nothing travels onward. Diff
/// the two folders and the difference is the fix this tool tells people to make.
public class IndirectKeptPrivateTests
{
    [Fact]
    public void A_carrier_that_keeps_its_reference_private_reaches_nobody()
    {
        var report = Fixtures.Check(Fixtures.IndirectKeptPrivate);

        Assert.Equal("clean", report.Verdict);
        Assert.Empty(report.Violations);
    }

    [Fact]
    public void It_is_the_same_codebase_as_IndirectReference_apart_from_the_private_markers()
    {
        var open = Fixtures.Check(Fixtures.IndirectReference);
        var kept = Fixtures.Check(Fixtures.IndirectKeptPrivate);

        // Same layers, same carriers, same number of references out of each. With the shapes
        // equal, the six findings on one side and none on the other can only be the markers.
        Assert.Equal(open.Shape(), kept.Shape());
        Assert.Equal(6, open.ViolationCount);
        Assert.Equal(0, kept.ViolationCount);
    }

    [Theory]
    [InlineData("Private.AppCarrier", "Private.Application")]
    [InlineData("Private.PresCarrier", "Private.Presentation")]
    [InlineData("Private.InfraCarrier", "Private.Infrastructure")]
    public void Each_carrier_still_references_the_layer_it_is_keeping_to_itself(string carrier, string layer)
    {
        var reference = Assert.Single(
            CsprojReader.Read(Fixtures.ProjectFile(Fixtures.IndirectKeptPrivate, carrier)).ProjectReferences
        );

        Assert.EndsWith($"{layer}.csproj", reference.ResolvedPath);
        Assert.True(reference.StopsTransitiveFlow);
    }
}

/// tests/fixtures/IndirectSharedHop — one carrier, two layers travelling through it. The point
/// is that a single bad edge is reported once per layer it reaches, not once in total.
public class IndirectSharedHopTests
{
    [Fact]
    public void One_bad_edge_is_reported_against_every_layer_it_reaches()
    {
        var report = Fixtures.Check(Fixtures.IndirectSharedHop);

        Assert.Equal(2, report.ViolationCount);
        Assert.Equal(
            ["Hop.Domain", "Hop.Carrier", "Hop.Infrastructure"],
            report.Between("Domain", "Infrastructure").Path
        );
        Assert.Equal(
            ["Hop.Application", "Hop.Domain", "Hop.Carrier", "Hop.Infrastructure"],
            report.Between("Application", "Infrastructure").Path
        );
    }

    [Fact]
    public void Both_findings_point_at_the_same_line_to_edit()
    {
        var report = Fixtures.Check(Fixtures.IndirectSharedHop);

        Assert.All(
            report.Violations,
            violation => Assert.EndsWith("Hop.Carrier.csproj", violation.FixAt.File)
        );
    }

    [Fact]
    public void The_allowed_hop_that_carried_it_is_not_itself_a_finding()
    {
        var report = Fixtures.Check(Fixtures.IndirectSharedHop);

        Assert.DoesNotContain(
            report.Violations,
            violation => violation is { FromProject: "Hop.Application", ToProject: "Hop.Domain" }
        );
    }
}
