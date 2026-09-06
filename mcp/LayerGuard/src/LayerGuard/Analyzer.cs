namespace LayerGuard;

/// One verdict, from every rule the ruleset states. The rule families live in their own files;
/// this only decides what runs and says afterwards what did not.
///
/// A family the rule file is silent about does not run, and the report says so by name. That is
/// the difference between "checked and clean" and "never looked", and a reader who cannot tell
/// them apart has been misled by a green result.
public static class Analyzer
{
    public const string ToolName = "layerguard";
    public const string ToolVersion = "0.2.0";

    public static Report Analyze(string path, string? configPath)
    {
        var ruleset = Ruleset.Load(path, configPath);
        var graph = ProjectGraph.Build(path, ruleset);

        var entryNodes = graph
            .EntryProjects.Where(graph.Nodes.ContainsKey)
            .Select(projectPath => graph.Nodes[projectPath])
            .ToList();
        var inScope = entryNodes.Where(node => node.InScope).OrderBy(node => node.Name).ToList();

        // Longest name first, so Acme.Billing.Domain claims a namespace before Acme.Billing would.
        var byLongestName = graph.Nodes.Values.OrderByDescending(node => node.Name.Length).ToList();
        var sources = SourceFiles.ByProject(graph.Nodes.Values);

        // Only built when a rule asks where a contract is declared: it costs a second read of
        // every source file, and no other family looks outside the file in front of it.
        var judgesContracts = ruleset.Declarations.Any(rule => rule.MustImplement is not null);
        var wantsIndex = judgesContracts || ruleset.ForbiddenDependencyOrigins.Count > 0;
        var declaredIn = wantsIndex
            ? DeclarationIndex.Build(inScope, sources)
            : new Dictionary<string, HashSet<Ring>>();

        var checkedFamilies = new List<string> { "project references" };
        var notChecked = new List<string>();
        var violations = new List<Violation>();
        var sourceFilesRead = 0;

        foreach (var node in inScope)
        {
            violations.AddRange(ReferenceRules.Direction(node, graph, ruleset));
            violations.AddRange(ReferenceRules.Named(node, graph, ruleset));
            violations.AddRange(PackageRules.For(node, ruleset));

            if (!sources.TryGetValue(node.FullPath, out var files))
                continue;

            foreach (var file in files.Order())
            {
                sourceFilesRead++;
                violations.AddRange(ImportRules.For(node, file, byLongestName, ruleset));
                violations.AddRange(DeclarationRules.For(node, file, ruleset, declaredIn));
                violations.AddRange(InjectionRules.For(node, file, ruleset, declaredIn));
            }
        }

        violations.AddRange(StructureRules.For(inScope, ruleset));

        if (sourceFilesRead > 0)
            checkedFamilies.Add($"import directives in {sourceFilesRead} source files");
        else
            notChecked.Add("import directives — no source file was found under the projects in scope");

        Record(
            ruleset.AllowedPackages.Count > 0,
            "which packages a ring may hold",
            "which packages a ring may hold — the rule file names none, so no package was judged",
            checkedFamilies,
            notChecked
        );
        Record(
            ruleset.AllowedReferences.Count > 0,
            "which projects a ring may name",
            "which projects a ring may name — the rule file lists none, so only the direction "
                + "table judged a reference",
            checkedFamilies,
            notChecked
        );
        Record(
            ruleset.ForbiddenPackages.Count > 0,
            "which packages a ring may never hold",
            "which packages a ring may never hold — the rule file forbids none by name",
            checkedFamilies,
            notChecked
        );
        Record(
            ruleset.Declarations.Count > 0,
            "where types of a given name must be declared",
            "where types must be declared — the rule file states no naming convention",
            checkedFamilies,
            notChecked
        );
        Record(
            ruleset.ForbiddenDependencies.Count > 0,
            "what a ring may be handed to hold",
            "what a ring may be handed to hold — the rule file forbids no constructor parameter",
            checkedFamilies,
            notChecked
        );
        Record(
            ruleset.ForbiddenDependencyOrigins.Count > 0,
            "which ring a type a ring is handed was declared in",
            "which ring a type a ring is handed was declared in — no rule asks",
            checkedFamilies,
            notChecked
        );
        Record(
            judgesContracts,
            "whether a type answers to a contract declared in another ring",
            "whether a type answers to a contract declared in another ring — no rule asks",
            checkedFamilies,
            notChecked
        );
        Record(
            ruleset.RequireRings,
            "every ring present in every module",
            "whether every module holds every ring — the rule file does not ask for it",
            checkedFamilies,
            notChecked
        );

        notChecked.AddRange(
            [
                "type names written out in full in code, with no import line",
                "which project a name really binds to — namespaces are matched against project "
                    + "names, not resolved by a compiler",
                "method bodies, and any use of a type that needs no import",
                "anything inside a project that matches no layer",
            ]
        );

        var ordered = violations
            .OrderBy(violation => violation.FromProject, StringComparer.Ordinal)
            .ThenBy(violation => violation.Rule, StringComparer.Ordinal)
            .ThenBy(violation => violation.Evidence.File, StringComparer.Ordinal)
            .ThenBy(violation => violation.Evidence.Line)
            .ToList();

        for (var index = 0; index < ordered.Count; index++)
        {
            var violation = ordered[index];
            var sameModule = violation.FromModule is not null && violation.FromModule == violation.ToModule;
            var claimed = Enum.TryParse<Ring>(violation.FromRing, out var fromRing)
                ? ruleset.RefFor(violation.Rule, fromRing, sameModule)
                : null;
            ordered[index] = violation with { Id = $"V{index + 1:D3}", Ref = claimed?.Ref };
        }

        var rulebook = ruleset
            .RuleRefs.Select(entry => new RuleRefResult(
                Ref: entry.Ref,
                Text: entry.Text,
                SettledBy: entry.Rules,
                Coverage: entry.Rules.Length == 0
                    ? "none"
                    : entry.NotMeasured is null
                        ? "full"
                        : "partial",
                NotMeasured: entry.NotMeasured,
                Findings: ordered.Count(violation => violation.Ref == entry.Ref)
            ))
            .ToList();

        Record(
            ruleset.RuleRefs.Count > 0,
            "every numbered rule of this codebase's own rulebook",
            "which numbered rule each finding answers to — the rule file states no rulebook, so "
                + "findings carry this tool's rule ids and nothing else",
            checkedFamilies,
            notChecked
        );

        return new Report(
            Tool: ToolName,
            ToolVersion: ToolVersion,
            Checked: checkedFamilies,
            Scope: new ScopeInfo(
                Root: graph.Root,
                RootKind: graph.RootKind,
                ProjectsLoaded: graph.Nodes.Count,
                ProjectsInScope: inScope.Count,
                ProjectsOutside: entryNodes.Count(node => !node.InScope)
            ),
            Ruleset: new RulesetInfo(
                ruleset.Source,
                ruleset.AllowedDependencies.ToDictionary(
                    pair => pair.Key.ToString(),
                    pair => pair.Value.Select(ring => ring.ToString()).ToArray()
                )
            ),
            Rulebook: rulebook,
            Verdict: ordered.Count == 0 ? "clean" : "violations",
            ViolationCount: ordered.Count,
            Violations: ordered,
            Projects: inScope.Select(Summarize).ToList(),
            Outside: entryNodes
                .Where(node => !node.InScope)
                .Select(Summarize)
                .OrderBy(project => project.Name)
                .ToList(),
            NotChecked: notChecked
        );
    }

    private static void Record(
        bool stated,
        string checkedWording,
        string silentWording,
        List<string> checkedFamilies,
        List<string> notChecked
    )
    {
        if (stated)
            checkedFamilies.Add(checkedWording);
        else
            notChecked.Add(silentWording);
    }

    internal static ProjectSummary Summarize(ProjectNode node) =>
        new(
            Name: node.Name,
            Ring: node.Ring.ToString(),
            Module: node.File.Module,
            File: node.FullPath,
            DirectProjectReferences: node.File.ProjectReferences.Count,
            Packages: node.File.PackageReferences.Count
        );
}
