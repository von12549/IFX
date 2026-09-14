using LayerGuard;
using Xunit;

namespace LayerGuard.Tests;

/// tests/fixtures/DisableTransitive — one carrier, two layers behind it. Domain sets
/// DisableTransitiveProjectReferences and sees nothing past what it names itself; Presentation
/// sets nothing and sees straight through. The contrast is the test: same carrier, same target,
/// one property between silence and a finding.
public class DisableTransitiveTests
{
    [Fact]
    public void A_layer_that_disabled_transitive_references_sees_nothing_past_its_own()
    {
        var report = Fixtures.Check(Fixtures.DisableTransitive);

        Assert.DoesNotContain(report.Violations, violation => violation.FromProject == "NoFlow.Domain");
    }

    [Fact]
    public void The_layer_beside_it_sees_straight_through_the_same_carrier()
    {
        var violation = Assert.Single(Fixtures.Check(Fixtures.DisableTransitive).Violations);

        Assert.Equal("NoFlow.Presentation", violation.FromProject);
        Assert.Equal("transitive", violation.Kind);
        Assert.Equal(["NoFlow.Presentation", "NoFlow.Carrier", "NoFlow.Infrastructure"], violation.Path);
    }

    [Fact]
    public void The_property_is_read_off_the_project_that_sets_it()
    {
        var domain = CsprojReader.Read(Fixtures.ProjectFile(Fixtures.DisableTransitive, "NoFlow.Domain"));
        var presentation = CsprojReader.Read(
            Fixtures.ProjectFile(Fixtures.DisableTransitive, "NoFlow.Presentation")
        );

        Assert.True(domain.TransitiveReferencesDisabled);
        Assert.False(presentation.TransitiveReferencesDisabled);
        Assert.Single(domain.ProjectReferences);
        Assert.Single(presentation.ProjectReferences);
    }
}

/// tests/fixtures/PrivateAssetsAttributeForm — the same stop written as an attribute rather
/// than a child element, beside a carrier that declares nothing. Both carriers point at the
/// same project, so only the attribute separates them.
public class PrivateAssetsAttributeFormTests
{
    [Fact]
    public void Private_written_as_an_attribute_stops_the_reference_too()
    {
        var report = Fixtures.Check(Fixtures.PrivateAssetsAttributeForm);

        Assert.DoesNotContain(report.Violations, violation => violation.FromProject == "Attr.Domain");
    }

    [Fact]
    public void The_carrier_that_declares_nothing_lets_it_through()
    {
        var violation = Assert.Single(Fixtures.Check(Fixtures.PrivateAssetsAttributeForm).Violations);

        Assert.Equal("Attr.Presentation", violation.FromProject);
        Assert.Equal(["Attr.Presentation", "Attr.OpenCarrier", "Attr.Infrastructure"], violation.Path);
    }

    [Fact]
    public void Both_carriers_point_at_the_same_project_so_only_the_attribute_separates_them()
    {
        var sealedCarrier = CsprojReader.Read(
            Fixtures.ProjectFile(Fixtures.PrivateAssetsAttributeForm, "Attr.SealedCarrier")
        );
        var openCarrier = CsprojReader.Read(
            Fixtures.ProjectFile(Fixtures.PrivateAssetsAttributeForm, "Attr.OpenCarrier")
        );

        Assert.EndsWith(
            "Attr.Infrastructure.csproj",
            Assert.Single(sealedCarrier.ProjectReferences).ResolvedPath
        );
        Assert.EndsWith(
            "Attr.Infrastructure.csproj",
            Assert.Single(openCarrier.ProjectReferences).ResolvedPath
        );
        Assert.True(sealedCarrier.ProjectReferences[0].StopsTransitiveFlow);
        Assert.False(openCarrier.ProjectReferences[0].StopsTransitiveFlow);
    }
}
