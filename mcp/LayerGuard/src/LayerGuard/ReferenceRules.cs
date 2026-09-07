namespace LayerGuard;

/// Rules read off the project files. Two of them: the direction table, and the list of projects
/// a ring may never name at all — which is the only way to state a rule about a project that
/// matches no ring, since the direction table has nothing to say about those.
public static class ReferenceRules
{
    public const string DirectionRule = "RING-DIRECTION";
    public const string ForbiddenRule = "FORBIDDEN-REFERENCE";
    public const string AllowedRule = "RING-REFERENCE";

    public static IEnumerable<Violation> Direction(ProjectNode node, ProjectGraph graph, Ruleset ruleset)
    {
        foreach (var (targetPath, chain) in graph.VisibleFrom(node.FullPath).OrderBy(entry => entry.Key))
        {
            if (!graph.Nodes.TryGetValue(targetPath, out var target) || !target.InScope)
                continue;
            if (ruleset.Allows(node.Ring, target.Ring))
                continue;

            var direct = chain.Count == 1;
            var lastEdge = chain[^1];

            yield return new Violation(
                Id: "",
                Rule: DirectionRule,
                Severity: ruleset.SeverityOf(DirectionRule),
                Headline: $"{node.Name} sees {target.Name}",
                FromProject: node.Name,
                FromRing: node.Ring.ToString(),
                FromModule: node.Module,
                ToProject: target.Name,
                ToRing: target.Ring.ToString(),
                ToModule: target.Module,
                Kind: direct ? "direct" : "transitive",
                Path: PathNames(node, chain),
                Evidence: chain[0].Source,
                FixAt: lastEdge.Source,
                FixHint: direct
                    ? $"Remove the reference to {target.Name} from {node.Name}."
                    : $"{node.Name} does not name {target.Name} itself. Close the last hop: add "
                        + $"PrivateAssets=\"all\" to {lastEdge.FromName}'s reference to {target.Name}, "
                        + $"or split {lastEdge.FromName} so it no longer carries it."
            );
        }
    }

    /// Every project this one names in its own file, judged against both lists the rule file may
    /// state about them: the projects a ring may never name, and the only projects it may. The
    /// reference has to be written in this project's own file — a rule about who may name a
    /// project is not a rule about who can reach it.
    public static IEnumerable<Violation> Named(ProjectNode node, ProjectGraph graph, Ruleset ruleset)
    {
        var allowed = ruleset.ReferencesAllowedIn(node.Ring);

        foreach (var reference in node.File.ProjectReferences)
        {
            var targetName = Path.GetFileNameWithoutExtension(reference.ResolvedPath);
            graph.Nodes.TryGetValue(reference.ResolvedPath, out var target);
            var targetModule = target?.Module;
            var sameModule = node.Module is not null && targetModule == node.Module;

            var pattern = ruleset.ForbidsReference(node.Ring, targetName, sameModule);
            if (pattern is null)
            {
                var offList = OffTheAllowList(node, target, targetName, targetModule, allowed, ruleset);
                if (offList is not null)
                    yield return offList;
                continue;
            }

            yield return new Violation(
                Id: "",
                Rule: ForbiddenRule,
                Severity: ruleset.SeverityOf(ForbiddenRule),
                Headline: $"{node.Name} references {targetName}",
                FromProject: node.Name,
                FromRing: node.Ring.ToString(),
                FromModule: node.Module,
                ToProject: targetName,
                ToRing: (target?.Ring ?? Ring.Outside).ToString(),
                ToModule: targetModule,
                Kind: sameModule ? "reference inside the module" : "reference",
                Path: [node.Name, targetName],
                Evidence: reference.Source,
                FixAt: reference.Source,
                FixHint: $"The rules forbid {node.Ring} projects from referencing `{pattern}`"
                    + (sameModule ? " inside their own module" : "")
                    + $". Remove the reference to {targetName} from {node.Name}."
            );
        }
    }

    /// A reference to a project the ring's allow-list does not name. A pair of rings the
    /// direction table already refuses is left alone: RING-DIRECTION reports that edge, and
    /// reporting it twice under two rules would make one mistake look like two.
    private static Violation? OffTheAllowList(
        ProjectNode node,
        ProjectNode? target,
        string targetName,
        string? targetModule,
        string[]? allowed,
        Ruleset ruleset
    )
    {
        if (allowed is null || allowed.Any(pattern => Ruleset.Matches(targetName, pattern)))
            return null;
        if (target is not null && target.InScope && !ruleset.Allows(node.Ring, target.Ring))
            return null;

        var reference = node.File.ProjectReferences.First(entry =>
            Path.GetFileNameWithoutExtension(entry.ResolvedPath) == targetName
        );

        return new Violation(
            Id: "",
            Rule: AllowedRule,
            Severity: ruleset.SeverityOf(AllowedRule),
            Headline: $"{node.Name} references {targetName}, which {node.Ring} may not name",
            FromProject: node.Name,
            FromRing: node.Ring.ToString(),
            FromModule: node.Module,
            ToProject: targetName,
            ToRing: (target?.Ring ?? Ring.Outside).ToString(),
            ToModule: targetModule,
            Kind: "reference",
            Path: [node.Name, targetName],
            Evidence: reference.Source,
            FixAt: reference.Source,
            FixHint: allowed.Length == 0
                ? $"{node.Ring} projects may name no other project at all. Remove the reference "
                    + $"to {targetName} from {node.Name}."
                : $"{node.Ring} projects may name only: {string.Join(", ", allowed)}. Remove the "
                    + $"reference to {targetName} from {node.Name}."
        );
    }

    private static List<string> PathNames(ProjectNode start, IReadOnlyList<GraphEdge> chain)
    {
        var names = new List<string> { start.Name };
        names.AddRange(chain.Select(edge => edge.ToName));
        return names;
    }
}
