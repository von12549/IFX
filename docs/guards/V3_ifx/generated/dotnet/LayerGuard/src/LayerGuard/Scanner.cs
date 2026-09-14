using Microsoft.CodeAnalysis;
using Microsoft.CodeAnalysis.CSharp;
using Microsoft.CodeAnalysis.CSharp.Syntax;

namespace LayerGuard;

/// Facts, with no verdict attached. Every rule in this tool is applied to what is listed here,
/// so a caller who wants to ask a question the rule file does not cover can ask it of the facts
/// directly instead of waiting for a new rule to exist.
public static class Scanner
{
    public static ScanResult Scan(
        string path,
        string select,
        string? configPath,
        string? ring,
        string? module,
        string? namePattern
    )
    {
        var ruleset = Ruleset.Load(path, configPath);
        var graph = ProjectGraph.Build(path, ruleset);

        var entryNodes = graph
            .EntryProjects.Where(graph.Nodes.ContainsKey)
            .Select(projectPath => graph.Nodes[projectPath])
            .ToList();

        var wanted = entryNodes
            .Where(node => ring is null || node.Ring.ToString().Equals(ring, StringComparison.OrdinalIgnoreCase))
            .Where(node => module is null || string.Equals(node.Module, module, StringComparison.OrdinalIgnoreCase))
            .OrderBy(node => node.Name)
            .ToList();

        var scope = new ScopeInfo(
            Root: graph.Root,
            RootKind: graph.RootKind,
            ProjectsLoaded: graph.Nodes.Count,
            ProjectsInScope: entryNodes.Count(node => node.InScope),
            ProjectsOutside: entryNodes.Count(node => !node.InScope)
        );
        var rules = new RulesetInfo(
            ruleset.Source,
            ruleset.PolicyHash,
            ruleset.AllowedDependencies.ToDictionary(
                pair => pair.Key.ToString(),
                pair => pair.Value.Select(r => r.ToString()).ToArray()
            ),
            ruleset.PolicyBindings,
            ruleset.WaiverPolicy
        );

        bool NameWanted(string name) => namePattern is null || Ruleset.Matches(name, namePattern);

        switch (select.ToLowerInvariant())
        {
            case "packages":
                {
                    var packages = wanted
                        .SelectMany(node =>
                            node.File.PackageReferences.Where(package => NameWanted(package.Id))
                                .Select(package => new PackageFact(
                                    node.Name,
                                    node.Ring.ToString(),
                                    node.Module,
                                    package.Id,
                                    package.Version,
                                    package.Source.File,
                                    package.Source.Line
                                ))
                        )
                        .ToList();
                    return new ScanResult(Analyzer.ToolName, "packages", scope, rules, packages.Count, Packages: packages);
                }

            case "imports":
                {
                    var byLongestName = graph.Nodes.Values.OrderByDescending(node => node.Name.Length).ToList();
                    var sources = SourceFiles.ByProject(graph.Nodes.Values);
                    var imports = new List<ImportFact>();

                    foreach (var node in wanted)
                    {
                        if (!sources.TryGetValue(node.FullPath, out var files))
                            continue;

                        foreach (var file in files.Order())
                            imports.AddRange(ImportsIn(node, file, byLongestName).Where(fact => NameWanted(fact.Target)));
                    }

                    return new ScanResult(Analyzer.ToolName, "imports", scope, rules, imports.Count, Imports: imports);
                }

            case "declarations":
                {
                    var sources = SourceFiles.ByProject(graph.Nodes.Values);
                    var declarations = new List<DeclarationFact>();

                    foreach (var node in wanted)
                    {
                        if (!sources.TryGetValue(node.FullPath, out var files))
                            continue;

                        foreach (var file in files.Order())
                            declarations.AddRange(DeclarationsIn(node, file).Where(fact => NameWanted(fact.Name)));
                    }

                    return new ScanResult(
                        Analyzer.ToolName,
                        "declarations",
                        scope,
                        rules,
                        declarations.Count,
                        Declarations: declarations
                    );
                }

            case "projects":
                {
                    var projects = wanted.Where(node => NameWanted(node.Name)).Select(Analyzer.Summarize).ToList();
                    return new ScanResult(Analyzer.ToolName, "projects", scope, rules, projects.Count, Projects: projects);
                }

            default:
                throw new ArgumentException(
                    $"\"{select}\" is not something to list. Use projects, packages, imports or declarations."
                );
        }
    }

    private static IEnumerable<ImportFact> ImportsIn(
        ProjectNode node,
        string file,
        IReadOnlyList<ProjectNode> byLongestName
    )
    {
        var tree = SourceFiles.Parse(file);
        var root = tree.GetRoot();

        foreach (var directive in root.DescendantNodes().OfType<UsingDirectiveSyntax>())
        {
            var fact = Describe(node, directive, file, tree.GetLineSpan(directive.Span).StartLinePosition.Line + 1, false, byLongestName);
            if (fact is not null)
                yield return fact;
        }

        foreach (var region in root.DescendantTrivia().Where(t => t.IsKind(SyntaxKind.DisabledTextTrivia)))
        {
            var regionStart = tree.GetLineSpan(region.Span).StartLinePosition.Line;
            var fragment = CSharpSyntaxTree.ParseText(region.ToFullString());

            foreach (var directive in fragment.GetRoot().DescendantNodes().OfType<UsingDirectiveSyntax>())
            {
                var within = fragment.GetLineSpan(directive.Span).StartLinePosition.Line;
                var fact = Describe(node, directive, file, regionStart + within + 1, true, byLongestName);
                if (fact is not null)
                    yield return fact;
            }
        }
    }

    private static ImportFact? Describe(
        ProjectNode node,
        UsingDirectiveSyntax directive,
        string file,
        int line,
        bool inactive,
        IReadOnlyList<ProjectNode> byLongestName
    )
    {
        var target = directive.NamespaceOrType?.ToString();
        if (target is null)
            return null;

        var declaring = ImportRules.DeclaringProject(target, byLongestName);
        return new ImportFact(
            node.Name,
            node.Ring.ToString(),
            node.Module,
            file,
            line,
            target,
            declaring?.Name,
            declaring is null ? (ImportRules.IsFrameworkNamespace(target) ? "framework" : "outside") : declaring.Ring.ToString(),
            inactive
        );
    }

    private static IEnumerable<DeclarationFact> DeclarationsIn(ProjectNode node, string file)
    {
        var tree = SourceFiles.Parse(file);

        foreach (var declaration in tree.GetRoot().DescendantNodes().OfType<BaseTypeDeclarationSyntax>())
        {
            yield return new DeclarationFact(
                node.Name,
                node.Ring.ToString(),
                node.Module,
                file,
                tree.GetLineSpan(declaration.Span).StartLinePosition.Line + 1,
                DeclarationRules.KindOf(declaration),
                declaration.Identifier.Text,
                declaration.BaseList?.Types.Select(t => t.ToString()).ToArray() ?? []
            );
        }
    }
}
