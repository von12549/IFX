namespace LayerGuard;

/// Whether the layers a codebase says it has are actually there. A missing ring is not a broken
/// dependency — nothing points the wrong way — so no other rule family would ever mention it,
/// and a module that quietly lost its Domain project would read as clean.
public static class StructureRules
{
    public const string Rule = "RING-MISSING";

    public static IEnumerable<Violation> For(IReadOnlyList<ProjectNode> inScope, Ruleset ruleset)
    {
        if (!ruleset.RequireRings)
            yield break;

        var expected = ruleset.RingPatterns.Keys.Where(ring => ring != Ring.Outside).Order().ToList();

        var modules = inScope
            .Where(node => node.Module is not null)
            .GroupBy(node => node.Module!)
            .OrderBy(group => group.Key);

        foreach (var module in modules)
        {
            var present = module.Select(node => node.Ring).ToHashSet();
            var anchor = module.OrderBy(node => node.Name).First();

            foreach (var ring in expected.Where(ring => !present.Contains(ring)))
            {
                var evidence = new SourceSpan(anchor.FullPath, 1, $"module {module.Key}");

                yield return new Violation(
                    Id: "",
                    Rule: Rule,
                    Severity: ruleset.SeverityOf(Rule, Ruleset.Drift),
                    Headline: $"module {module.Key} has no {ring} project",
                    FromProject: module.Key,
                    FromRing: ring.ToString(),
                    FromModule: module.Key,
                    ToProject: ring.ToString(),
                    ToRing: ring.ToString(),
                    ToModule: module.Key,
                    Kind: "missing ring",
                    Path: [module.Key],
                    Evidence: evidence,
                    FixAt: evidence,
                    FixHint: $"The rules expect every module to hold a {ring} project. "
                        + $"Module {module.Key} holds "
                        + $"{string.Join(", ", present.Order().Select(r => r.ToString()))}."
                );
            }
        }
    }
}
