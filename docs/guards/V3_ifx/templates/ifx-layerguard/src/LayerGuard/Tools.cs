using System.ComponentModel;
using ModelContextProtocol.Server;

namespace LayerGuard;

/// Three tools, and the split between them is the point. `check` judges, and every rule it
/// applies comes from a file a person wrote and can be shown. `scan` only lists, so a question
/// no rule covers can still be answered without inventing a rule at run time. `describe_rules`
/// says what `check` would apply, so a verdict can be read back to the rules that produced it.
[McpServerToolType]
public static class Tools
{
    [McpServerTool(Name = "check")]
    [Description(
        "Check a .NET codebase against the Clean Architecture rules stated for it. Give it one path: "
            + "a .csproj checks that project, a folder checks every project under it, a .sln checks the "
            + "solution. Applies every rule the rule file states — layer direction across project "
            + "references and across import directives, which packages a ring may hold, projects a ring "
            + "may never name, where types of a given name must be declared, and whether every module "
            + "holds every ring. Returns each finding with the file and line to open, and names the rule "
            + "families the rule file left silent, so a clean result is never mistaken for a complete "
            + "one. Parses rather than compiles: it answers on code that does not build. Reads only."
    )]
    public static string Check(
        [Description("Path to a .csproj, a folder, or a .sln.")] string path,
        [Description(
            "Optional path to a layerguard.json. Omitted means walk up from `path` looking for one, then fall back to the built-in rules."
        )]
            string? configPath = null,
        [Description(
            "json for fields to act on, markdown for something a person reads, both for the two together. Default json."
        )]
            string format = "json"
    )
    {
        var report = Analyzer.Analyze(path, configPath);
        return format.ToLowerInvariant() switch
        {
            "markdown" => ReportWriter.ToMarkdown(report),
            "both" => ReportWriter.ToJson(report) + "\n\n" + ReportWriter.ToMarkdown(report),
            _ => ReportWriter.ToJson(report),
        };
    }

    [McpServerTool(Name = "scan")]
    [Description(
        "List what is in a codebase, with no verdict attached. `select` picks what to list: "
            + "projects (each with the ring it was assigned and what it declares), packages (every "
            + "PackageReference), imports (every using directive, with the project and ring the "
            + "namespace belongs to, and whether it sits in a branch the preprocessor turned off), or "
            + "declarations (every type declared, its kind, its name and its base types). Narrow the "
            + "result with ring, module or namePattern. Use this to answer a question the rule file "
            + "does not cover, instead of reading the source. Reads only."
    )]
    public static string Scan(
        [Description("Path to a .csproj, a folder, or a .sln.")] string path,
        [Description("What to list: projects, packages, imports or declarations. Default projects.")]
            string select = "projects",
        [Description("Optional explicit path to a layerguard.json.")] string? configPath = null,
        [Description("Only this ring: Domain, Application, Presentation, Infrastructure or Outside.")]
            string? ring = null,
        [Description("Only this module — the folder a project sits in, as `scan` reports it.")]
            string? module = null,
        [Description(
            "Only names matching this pattern, `*` allowed. Matched against the project name, the "
                + "package id, the imported namespace or the type name, depending on `select`."
        )]
            string? namePattern = null
    ) => ReportWriter.ToJson(Scanner.Scan(path, select, configPath, ring, module, namePattern));

    [McpServerTool(Name = "describe_rules")]
    [Description(
        "The rules `check` would apply to a path: which project names count as which layer, which "
            + "layer may depend on which, which packages each ring may hold, which projects are "
            + "forbidden, where types must be declared, and what nothing here looks at. Call it before "
            + "`check` when the rules matter to the answer, or after one to read a verdict back to the "
            + "rule that produced it."
    )]
    public static string DescribeRules(
        [Description("Optional path used to find a layerguard.json by walking up from it.")] string? path = null,
        [Description("Optional explicit path to a layerguard.json.")] string? configPath = null
    )
    {
        var ruleset = Ruleset.Load(path ?? Directory.GetCurrentDirectory(), configPath);
        return RuleDescription.Render(ruleset);
    }
}
