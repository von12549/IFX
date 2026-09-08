namespace LayerGuard;

/// Ownership-aware checks are separate from layer direction: Application -> Contracts is a
/// legal role pair, but only when both projects belong to the same module.
public static class OwnershipRules
{
    public const string UnknownOwnershipRule = "OWNERSHIP-UNKNOWN";
    public const string ProjectNameRule = "PROJECT-NAME-FORBIDDEN";
    public const string ScopeRule = "OWNERSHIP-REFERENCE";
    public const string ProviderRule = "PROVIDER-CONTRACT";
    public const string ProviderCycleRule = "PROVIDER-CYCLE";
    public const string ContractCycleRule = "CONTRACT-CYCLE";

    public static IEnumerable<Violation> For(ProjectNode node, ProjectGraph graph, Ruleset ruleset)
    {
        if (ruleset.RequireKnownOwnership && node.Ring is not (Ring.RuntimeHost or Ring.Test) && node.Module is null)
            yield return Finding(
                UnknownOwnershipRule,
                ruleset,
                node,
                node.Name,
                node.Ring,
                null,
                "ownership",
                new SourceSpan(node.FullPath, 1, node.Name),
                $"Add a matching ownership.modulePatterns entry for {node.Name}."
            );

        var forbiddenName = ruleset.ForbiddenProjectNames.FirstOrDefault(pattern =>
            Ruleset.Matches(node.Name, pattern)
        );
        if (forbiddenName is not null)
            yield return Finding(
                ProjectNameRule,
                ruleset,
                node,
                node.Name,
                node.Ring,
                node.Module,
                "project declaration",
                new SourceSpan(node.FullPath, 1, node.Name),
                $"Projects matching `{forbiddenName}` are migration-only. Create a provider-owned .Contracts project instead."
            );

        foreach (var (targetPath, chain) in graph.VisibleFrom(node.FullPath).OrderBy(pair => pair.Key))
        {
            if (!graph.Nodes.TryGetValue(targetPath, out var target) || !target.InScope)
                continue;
            if (!ruleset.Allows(node.Ring, target.Ring))
                continue;
            if (ruleset.IsSharedPrimitiveReference(node, target.Name))
                continue;
            if (ruleset.AllowsOwnership(node.Ring, target.Ring, node.Module, target.Module))
                continue;

            var direct = chain.Count == 1;
            yield return new Violation(
                "",
                ScopeRule,
                ruleset.SeverityOf(ScopeRule),
                $"{node.Name} sees {Relationship(node.Module, target.Module)} {target.Name}",
                node.Name,
                node.Ring.ToString(),
                node.Module,
                target.Name,
                target.Ring.ToString(),
                target.Module,
                direct ? "direct ownership reference" : "transitive ownership reference",
                [node.Name, .. chain.Select(edge => edge.ToName)],
                chain[0].Source,
                chain[^1].Source,
                $"{node.Ring} may not depend on {Relationship(node.Module, target.Module)} {target.Ring}. "
                    + (direct
                        ? $"Remove the reference to {target.Name}."
                        : $"Stop the transitive flow at {chain[^1].FromName} -> {target.Name}.")
            );
        }

        if (node.Ring != Ring.IntegrationAdapter || node.Module is null)
            yield break;

        foreach (var reference in node.File.ProjectReferences)
        {
            if (!graph.Nodes.TryGetValue(reference.ResolvedPath, out var target)
                || target.Ring != Ring.Contracts
                || target.Module is null
                || string.Equals(node.Module, target.Module, StringComparison.OrdinalIgnoreCase)
                || ruleset.IsApprovedProvider(node.Module, target.Module))
                continue;

            yield return Finding(
                ProviderRule,
                ruleset,
                node,
                target.Name,
                target.Ring,
                target.Module,
                "unregistered provider contract",
                reference.Source,
                $"Register provider `{target.Module}` for consumer `{node.Module}` in providerContracts, or remove the reference."
            );
        }
    }

    public static IEnumerable<Violation> Graph(ProjectGraph graph, Ruleset ruleset)
    {
        foreach (var cycle in Cycles(ruleset.ProviderContracts))
        {
            var first = cycle[0];
            var source = graph.Nodes.Values.FirstOrDefault(node =>
                string.Equals(node.Module, first, StringComparison.OrdinalIgnoreCase)
            );
            var span = source is null
                ? new SourceSpan(ruleset.Source, 1, string.Join(" -> ", cycle))
                : new SourceSpan(source.FullPath, 1, string.Join(" -> ", cycle));
            yield return new Violation(
                "",
                ProviderCycleRule,
                ruleset.SeverityOf(ProviderCycleRule),
                $"Provider graph contains a cycle: {string.Join(" -> ", cycle)}",
                source?.Name ?? first,
                source?.Ring.ToString() ?? Ring.Outside.ToString(),
                first,
                cycle[^1],
                Ring.Contracts.ToString(),
                cycle[^1],
                "provider graph cycle",
                cycle,
                span,
                new SourceSpan(ruleset.Source, 1, string.Join(" -> ", cycle)),
                "Break the synchronous provider cycle; use an event or invert one dependency."
            );
        }

        foreach (var cycle in ContractCycles(graph))
        {
            var first = graph.Nodes.Values.Single(node => node.Name == cycle[0]);
            var reference = first.File.ProjectReferences.First(item =>
                Path.GetFileNameWithoutExtension(item.ResolvedPath) == cycle[1]
            );
            yield return new Violation(
                "",
                ContractCycleRule,
                ruleset.SeverityOf(ContractCycleRule),
                $"Contracts project cycle: {string.Join(" -> ", cycle)}",
                first.Name,
                first.Ring.ToString(),
                first.Module,
                cycle[^1],
                Ring.Contracts.ToString(),
                first.Module,
                "Contracts project cycle",
                cycle,
                reference.Source,
                reference.Source,
                "Remove the Contracts-to-Contracts cycle; extract an approved primitive or redesign the capability boundary."
            );
        }
    }

    private static IEnumerable<IReadOnlyList<string>> ContractCycles(ProjectGraph graph)
    {
        var contractGraph = graph.Nodes.Values.Where(node => node.Ring == Ring.Contracts)
            .ToDictionary(
                node => node.Name,
                node => node.File.ProjectReferences
                    .Select(reference => graph.Nodes.TryGetValue(reference.ResolvedPath, out var target) ? target : null)
                    .Where(target => target?.Ring == Ring.Contracts)
                    .Select(target => target!.Name)
                    .ToArray(),
                StringComparer.OrdinalIgnoreCase
            );
        return Cycles(contractGraph);
    }

    private static IEnumerable<IReadOnlyList<string>> Cycles(IReadOnlyDictionary<string, string[]> graph)
    {
        var emitted = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        foreach (var start in graph.Keys.Order(StringComparer.OrdinalIgnoreCase))
        {
            var path = new List<string>();
            var active = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
            foreach (var cycle in Visit(start, graph, path, active))
            {
                var key = string.Join("|", cycle.Order(StringComparer.OrdinalIgnoreCase));
                if (emitted.Add(key))
                    yield return cycle;
            }
        }
    }

    private static IEnumerable<IReadOnlyList<string>> Visit(
        string node,
        IReadOnlyDictionary<string, string[]> graph,
        List<string> path,
        HashSet<string> active
    )
    {
        if (active.Contains(node))
        {
            var start = path.FindIndex(item => item.Equals(node, StringComparison.OrdinalIgnoreCase));
            yield return [.. path.Skip(start), node];
            yield break;
        }
        active.Add(node);
        path.Add(node);
        if (graph.TryGetValue(node, out var targets))
            foreach (var target in targets)
                foreach (var cycle in Visit(target, graph, path, active))
                    yield return cycle;
        path.RemoveAt(path.Count - 1);
        active.Remove(node);
    }

    private static string Relationship(string? source, string? target) =>
        source is not null && string.Equals(source, target, StringComparison.OrdinalIgnoreCase)
            ? "own"
            : "foreign";

    private static Violation Finding(
        string rule,
        Ruleset ruleset,
        ProjectNode node,
        string target,
        Ring targetRole,
        string? targetModule,
        string kind,
        SourceSpan evidence,
        string hint
    ) => new(
        "",
        rule,
        ruleset.SeverityOf(rule),
        $"{node.Name}: {kind}",
        node.Name,
        node.Ring.ToString(),
        node.Module,
        target,
        targetRole.ToString(),
        targetModule,
        kind,
        [node.Name, target],
        evidence,
        evidence,
        hint
    );
}
