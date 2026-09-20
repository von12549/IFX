using System.Text;
using System.Text.Json;
using System.Text.Json.Serialization;

namespace LayerGuard;

public static class ReportWriter
{
    private static readonly JsonSerializerOptions JsonOptions =
        new()
        {
            WriteIndented = true,
            PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
            DefaultIgnoreCondition = JsonIgnoreCondition.WhenWritingNull,
        };

    public static string ToJson(Report report) => JsonSerializer.Serialize(report, JsonOptions);

    public static string ToJson(ScanResult result) => JsonSerializer.Serialize(result, JsonOptions);

    public static string ToJson(ArchitectureGraphReport result) => JsonSerializer.Serialize(result, JsonOptions);

    public static string ToMarkdown(Report report)
    {
        var text = new StringBuilder();

        text.AppendLine($"# Layer check — {report.Verdict}");
        text.AppendLine();
        text.AppendLine(
            report.ViolationCount == 0
                ? $"{report.Scope.ProjectsInScope} projects checked, no dependency points the wrong way."
                : $"{report.Scope.ProjectsInScope} projects checked, {report.ViolationCount} findings."
        );
        text.AppendLine();
        text.AppendLine($"- Rules: {report.Ruleset.Source}");
        text.AppendLine($"- Root: `{report.Scope.Root}`");
        text.AppendLine($"- Outside the check: {report.Scope.ProjectsOutside} projects");
        if (report.Baseline is not null)
            text.AppendLine($"- Baseline: {report.Baseline.Matched} matched, {report.Baseline.New} new, {report.Baseline.Stale} stale");
        text.AppendLine();
        text.AppendLine("## Checked");
        text.AppendLine();
        foreach (var item in report.Checked)
            text.AppendLine($"- {item}");
        text.AppendLine();

        if (report.ViolationCount > 0)
        {
            text.AppendLine("## Violations");
            text.AppendLine();
            foreach (var violation in report.Violations)
            {
                text.AppendLine($"### {violation.Id} — {violation.Headline}");
                text.AppendLine();
                text.AppendLine($"- **Rule** {violation.Rule} ({violation.Severity})");
                text.AppendLine($"- **Found as** {violation.Kind}");
                if (violation.Path.Count > 1)
                    text.AppendLine($"- **Path** {string.Join(" → ", violation.Path)}");
                text.AppendLine($"- **Read at** `{violation.Evidence.File}:{violation.Evidence.Line}`");
                var language = violation.Evidence.File.EndsWith(".cs") ? "csharp" : "xml";
                text.AppendLine($"  ```{language}");
                text.AppendLine($"  {violation.Evidence.Text}");
                text.AppendLine($"  ```");
                text.AppendLine($"- **Fix at** `{violation.FixAt.File}:{violation.FixAt.Line}`");
                text.AppendLine($"- **How** {violation.FixHint}");
                text.AppendLine();
            }
        }

        text.AppendLine("## Projects checked");
        text.AppendLine();
        text.AppendLine("| project | ring | module | direct refs | packages |");
        text.AppendLine("| --- | --- | --- | --- | --- |");
        foreach (var project in report.Projects)
            text.AppendLine(
                $"| {project.Name} | {project.Ring} | {project.Module ?? ""} | {project.DirectProjectReferences} | {project.Packages} |"
            );
        text.AppendLine();

        if (report.Outside.Count > 0)
        {
            text.AppendLine("## Outside the check");
            text.AppendLine();
            text.AppendLine("These projects match no ring, so nothing here rules on them.");
            text.AppendLine();
            foreach (var project in report.Outside)
                text.AppendLine($"- {project.Name}");
            text.AppendLine();
        }

        text.AppendLine("## Not checked");
        text.AppendLine();
        foreach (var item in report.NotChecked)
            text.AppendLine($"- {item}");

        return text.ToString();
    }
}
