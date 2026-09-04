using System.Text.Json;
using LayerGuard;
using Xunit;

namespace LayerGuard.Tests;

/// What a caller actually receives. The structured form is what a model reads fields out of;
/// the rendered form is what a person reads. Both have to carry the chain and the line to edit,
/// because a finding without those two is a finding nobody can act on.
public class ReportFormatTests
{
    [Fact]
    public void The_structured_form_carries_every_field_a_caller_needs_to_act()
    {
        var json = JsonDocument.Parse(ReportWriter.ToJson(Fixtures.Check(Fixtures.IndirectSharedHop)));
        var violation = json.RootElement.GetProperty("violations")[0];

        Assert.Equal("RING-DIRECTION", violation.GetProperty("rule").GetString());
        Assert.Equal("breaks", violation.GetProperty("severity").GetString());
        Assert.Equal("transitive", violation.GetProperty("kind").GetString());
        Assert.EndsWith("Hop.Carrier.csproj", violation.GetProperty("fixAt").GetProperty("file").GetString());
        Assert.True(violation.GetProperty("fixAt").GetProperty("line").GetInt32() > 0);
        Assert.NotEmpty(violation.GetProperty("path").EnumerateArray());
    }

    [Fact]
    public void The_structured_form_names_its_own_limits()
    {
        var json = JsonDocument.Parse(ReportWriter.ToJson(Fixtures.Check(Fixtures.AllowedDirections)));

        Assert.Equal("clean", json.RootElement.GetProperty("verdict").GetString());
        Assert.Contains(
            json.RootElement.GetProperty("checked").EnumerateArray(),
            item => item.GetString() == "project references"
        );
        Assert.NotEmpty(json.RootElement.GetProperty("notChecked").EnumerateArray());
    }

    [Fact]
    public void The_rendered_form_shows_the_whole_chain_and_the_line_to_edit()
    {
        var markdown = ReportWriter.ToMarkdown(Fixtures.Check(Fixtures.IndirectSharedHop));

        Assert.Contains("Hop.Domain → Hop.Carrier → Hop.Infrastructure", markdown);
        Assert.Contains("Hop.Application → Hop.Domain → Hop.Carrier → Hop.Infrastructure", markdown);
        Assert.Matches(@"\*\*Fix at\*\* `[^`]*Hop\.Carrier\.csproj:\d+`", markdown);
        Assert.Contains("Close the last hop", markdown);
    }

    [Fact]
    public void A_clean_rendering_still_says_what_was_not_looked_at()
    {
        var markdown = ReportWriter.ToMarkdown(Fixtures.Check(Fixtures.AllowedDirections));

        Assert.Contains("no dependency points the wrong way", markdown);
        Assert.Contains("## Not checked", markdown);
        Assert.DoesNotContain("## Violations", markdown);
    }

    [Fact]
    public void The_tool_returns_the_structured_form_unless_asked_for_the_rendered_one()
    {
        var path = Fixtures.PathTo(Fixtures.IndirectSharedHop);

        Assert.StartsWith("{", Tools.Check(path).TrimStart());
        Assert.StartsWith("{", Tools.Check(path, format: "json").TrimStart());
        Assert.StartsWith("# Layer check", Tools.Check(path, format: "markdown").TrimStart());
    }

    [Fact]
    public void The_rules_tool_answers_without_a_codebase()
    {
        var rules = Tools.DescribeRules();

        Assert.Contains("Domain", rules);
        Assert.Contains("refused", rules);
        Assert.Contains("transitive", rules);
    }
}
