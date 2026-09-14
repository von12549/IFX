namespace LayerGuard;

/// Every project reachable from the entry path, plus the compile-time visibility walk.
public sealed class ProjectGraph
{
    private readonly Dictionary<string, ProjectNode> nodes = new(StringComparer.OrdinalIgnoreCase);
    private Ruleset ActiveRuleset { get; init; } = Ruleset.Default;

    public required string Root { get; init; }
    public required string RootKind { get; init; }
    public required IReadOnlyList<string> EntryProjects { get; init; }
    public IReadOnlyDictionary<string, ProjectNode> Nodes => nodes;

    public static ProjectGraph Build(string path, Ruleset ruleset)
    {
        var normalized = Paths.Normalize(path);
        var (kind, entries) = Discover(normalized);

        var graph = new ProjectGraph
        {
            Root = normalized,
            RootKind = kind,
            EntryProjects = entries,
            ActiveRuleset = ruleset,
        };

        var pending = new Queue<string>(entries);
        while (pending.Count > 0)
        {
            var projectPath = pending.Dequeue();
            if (graph.nodes.ContainsKey(projectPath) || !File.Exists(projectPath))
                continue;

            var file = CsprojReader.Read(projectPath);
            var role = ruleset.RingOf(file.Name);
            graph.nodes[projectPath] = new ProjectNode(file, role, ruleset.ModuleOf(file, role));

            foreach (var reference in file.ProjectReferences)
                pending.Enqueue(reference.ResolvedPath);
        }

        return graph;
    }

    /// What the root project can see at compile time, and by which chain of references.
    /// A direct reference is always visible. Past that, an edge marked private to its owner
    /// does not flow onward, and a project that disabled transitive references sees only depth one.
    public IReadOnlyDictionary<string, IReadOnlyList<GraphEdge>> VisibleFrom(string rootPath)
    {
        var reached = new Dictionary<string, IReadOnlyList<GraphEdge>>(StringComparer.OrdinalIgnoreCase);
        if (!nodes.TryGetValue(rootPath, out var root))
            return reached;

        var frontier = new Queue<(string Path, List<GraphEdge> Chain)>();

        foreach (var edge in EdgesOf(root))
        {
            if (reached.ContainsKey(edge.ToPath))
                continue;
            var chain = new List<GraphEdge> { edge };
            reached[edge.ToPath] = chain;
            frontier.Enqueue((edge.ToPath, chain));
        }

        if (root.File.TransitiveReferencesDisabled)
            return reached;

        while (frontier.Count > 0)
        {
            var (currentPath, chain) = frontier.Dequeue();
            if (!nodes.TryGetValue(currentPath, out var current))
                continue;
            if (ActiveRuleset.TransitiveBoundaryRoles.Contains(current.Ring))
                continue;

            foreach (var edge in EdgesOf(current))
            {
                if (edge.StopsTransitiveFlow || reached.ContainsKey(edge.ToPath) || Paths.SamePath(edge.ToPath, rootPath))
                    continue;
                var next = new List<GraphEdge>(chain) { edge };
                reached[edge.ToPath] = next;
                frontier.Enqueue((edge.ToPath, next));
            }
        }

        return reached;
    }

    private IEnumerable<GraphEdge> EdgesOf(ProjectNode node) =>
        node.File.ProjectReferences.Select(reference => new GraphEdge(
            FromPath: node.FullPath,
            FromName: node.Name,
            ToPath: reference.ResolvedPath,
            ToName: NameOf(reference.ResolvedPath),
            Source: reference.Source,
            StopsTransitiveFlow: reference.StopsTransitiveFlow
        ));

    private string NameOf(string projectPath) =>
        nodes.TryGetValue(projectPath, out var node) ? node.Name : Path.GetFileNameWithoutExtension(projectPath);

    private static (string Kind, IReadOnlyList<string> Projects) Discover(string path)
    {
        if (Directory.Exists(path))
            return (
                "directory",
                Directory.EnumerateFiles(path, "*.csproj", SearchOption.AllDirectories).Select(Paths.Normalize).ToList()
            );

        if (path.EndsWith(".csproj", StringComparison.OrdinalIgnoreCase))
            return ("project", [path]);

        if (path.EndsWith(".sln", StringComparison.OrdinalIgnoreCase) || path.EndsWith(".slnx", StringComparison.OrdinalIgnoreCase))
            return ("solution", SolutionProjects(path));

        throw new ArgumentException($"{path} is not a .csproj, a .sln, or a folder.");
    }

    private static IReadOnlyList<string> SolutionProjects(string solutionPath)
    {
        var solutionDir = Path.GetDirectoryName(solutionPath)!;
        var projects = new List<string>();

        foreach (var line in File.ReadLines(solutionPath))
        {
            foreach (var field in line.Split('"'))
            {
                if (!field.EndsWith(".csproj", StringComparison.OrdinalIgnoreCase))
                    continue;
                var candidate = Paths.Normalize(
                    Path.Combine(solutionDir, field.Replace('\\', Path.DirectorySeparatorChar))
                );
                if (File.Exists(candidate))
                    projects.Add(candidate);
            }
        }

        return projects.Distinct(StringComparer.OrdinalIgnoreCase).ToList();
    }
}
