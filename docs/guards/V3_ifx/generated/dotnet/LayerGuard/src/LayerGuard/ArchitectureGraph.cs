using Microsoft.CodeAnalysis.CSharp.Syntax;

namespace LayerGuard;

public sealed record ProjectEdge(
    string From,
    string FromRole,
    string? FromModule,
    string To,
    string ToRole,
    string? ToModule
);

public sealed record NamespaceEdge(
    string From,
    string FromRole,
    string? FromModule,
    string To,
    string ToRole,
    string? ToModule,
    int Uses
);

public sealed record ArchitectureGraphReport(
    string Tool,
    string ToolVersion,
    string Ruleset,
    ScopeInfo Scope,
    IReadOnlyList<ProjectEdge> ProjectEdges,
    IReadOnlyList<NamespaceEdge> NamespaceEdges,
    IReadOnlyList<string> OutsideProjects
);

public static class ArchitectureGraph
{
    public static ArchitectureGraphReport Build(string path, string? configPath)
    {
        var ruleset = Ruleset.Load(path, configPath);
        var graph = ProjectGraph.Build(path, ruleset);
        var entries = graph.EntryProjects.Where(graph.Nodes.ContainsKey).Select(item => graph.Nodes[item]).ToList();
        var projects = graph.Nodes.Values.OrderByDescending(item => item.Name.Length).ToList();
        var sources = SourceFiles.ByProject(graph.Nodes.Values);

        var projectEdges = entries.SelectMany(node => node.File.ProjectReferences.Select(reference =>
        {
            graph.Nodes.TryGetValue(reference.ResolvedPath, out var target);
            return new ProjectEdge(
                node.Name,
                node.Ring.ToString(),
                node.Module,
                target?.Name ?? Path.GetFileNameWithoutExtension(reference.ResolvedPath),
                (target?.Ring ?? Ring.Outside).ToString(),
                target?.Module
            );
        })).OrderBy(edge => edge.From).ThenBy(edge => edge.To).ToList();

        var namespaceUses = new List<(ProjectNode From, ProjectNode To)>();
        foreach (var node in entries.Where(item => item.InScope))
        {
            if (!sources.TryGetValue(node.FullPath, out var files))
                continue;
            foreach (var file in files)
            {
                var root = SourceFiles.Parse(file).GetRoot();
                foreach (var directive in root.DescendantNodes().OfType<UsingDirectiveSyntax>())
                {
                    var targetName = directive.NamespaceOrType?.ToString();
                    var target = targetName is null ? null : ImportRules.DeclaringProject(targetName, projects);
                    if (target is not null && target.FullPath != node.FullPath)
                        namespaceUses.Add((node, target));
                }
            }
        }

        var namespaceEdges = namespaceUses
            .GroupBy(item => new
            {
                item.From.Name,
                FromRole = item.From.Ring,
                FromModule = item.From.Module,
                ToName = item.To.Name,
                ToRole = item.To.Ring,
                ToModule = item.To.Module,
            })
            .Select(group => new NamespaceEdge(
                group.Key.Name,
                group.Key.FromRole.ToString(),
                group.Key.FromModule,
                group.Key.ToName,
                group.Key.ToRole.ToString(),
                group.Key.ToModule,
                group.Count()
            ))
            .OrderBy(edge => edge.From)
            .ThenBy(edge => edge.To)
            .ToList();

        return new ArchitectureGraphReport(
            Analyzer.ToolName,
            Analyzer.ToolVersion,
            ruleset.Source,
            new ScopeInfo(
                graph.Root,
                graph.RootKind,
                graph.Nodes.Count,
                entries.Count(item => item.InScope),
                entries.Count(item => !item.InScope)
            ),
            projectEdges,
            namespaceEdges,
            entries.Where(item => !item.InScope).Select(item => item.Name).Order().ToList()
        );
    }
}
