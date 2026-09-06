using LayerGuard;
using Xunit;

namespace LayerGuard.Tests;

/// tests/fixtures/DirectReference — four projects, every refused pair written into the
/// referencing project's own file. Six of the seven refused pairs live here; the seventh,
/// Infrastructure depending on Presentation, is in DirectSiblingReference because putting it
/// beside Presentation depending on Infrastructure would make the two reference each other.
public class DirectReferenceTests
{
    [Theory]
    [InlineData("Domain", "Application")]
    [InlineData("Domain", "Presentation")]
    [InlineData("Domain", "Infrastructure")]
    [InlineData("Application", "Presentation")]
    [InlineData("Application", "Infrastructure")]
    [InlineData("Presentation", "Infrastructure")]
    public void The_refused_pair_is_reported(string from, string to)
    {
        var violation = Fixtures.Check(Fixtures.DirectReference).Between(from, to);

        Assert.Equal("direct", violation.Kind);
        Assert.Equal("breaks", violation.Severity);
        Assert.Equal([$"Direct.{from}", $"Direct.{to}"], violation.Path);
    }

    [Theory]
    [InlineData("Domain", "Application")]
    [InlineData("Domain", "Presentation")]
    [InlineData("Domain", "Infrastructure")]
    [InlineData("Application", "Presentation")]
    [InlineData("Application", "Infrastructure")]
    [InlineData("Presentation", "Infrastructure")]
    public void The_fix_is_the_line_that_wrote_the_reference(string from, string to)
    {
        var violation = Fixtures.Check(Fixtures.DirectReference).Between(from, to);

        Assert.EndsWith($"Direct.{from}.csproj", violation.FixAt.File);
        Assert.True(violation.FixAt.Line > 0);
        Assert.Contains($"Direct.{to}", violation.FixAt.Text);
        Assert.Contains("Remove the reference", violation.FixHint);
    }

    [Fact]
    public void The_fixture_holds_six_refused_pairs_and_nothing_else()
    {
        var report = Fixtures.Check(Fixtures.DirectReference);

        Assert.Equal("violations", report.Verdict);
        Assert.Equal(6, report.ViolationCount);
        Assert.All(report.Violations, violation => Assert.Equal("direct", violation.Kind));
    }
}

/// tests/fixtures/DirectSiblingReference — the seventh refused pair. Presentation and
/// Infrastructure are both outer layers and neither may see the other; this fixture holds the
/// direction the other fixture cannot.
public class DirectSiblingReferenceTests
{
    [Fact]
    public void Infrastructure_may_not_see_Presentation()
    {
        var report = Fixtures.Check(Fixtures.DirectSiblingReference);
        var violation = Assert.Single(report.Violations);

        Assert.Equal("direct", violation.Kind);
        Assert.Equal("Infrastructure", violation.FromRing);
        Assert.Equal("Presentation", violation.ToRing);
        Assert.Equal(["Sibling.Infrastructure", "Sibling.Presentation"], violation.Path);
        Assert.EndsWith("Sibling.Infrastructure.csproj", violation.FixAt.File);
    }
}
