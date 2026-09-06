namespace LayerGuard;

/// What a ring may take from outside the codebase. A layer with no package rule is not checked;
/// a layer with an empty one may hold nothing at all. This is the only family that reaches the
/// findings the direction table structurally cannot see: a package carries no ring, so a
/// database library sitting in Domain breaks nothing the reference graph knows about.
public static class PackageRules
{
    public const string Rule = "RING-PACKAGE";
    public const string ForbiddenRule = "RING-PACKAGE-FORBIDDEN";

    public static IEnumerable<Violation> For(ProjectNode node, Ruleset ruleset)
    {
        var allowed = ruleset.PackagesAllowedIn(node.Ring);

        foreach (var package in node.File.PackageReferences)
        {
            // The deny-list is read first, so a package both lists name is reported once, under
            // the rule that names it rather than the rule that merely fails to allow it.
            var forbidden = ruleset.ForbidsPackage(node.Ring, package.Id);
            if (forbidden is not null)
            {
                yield return Refuse(node, package.Id, package.Source, forbidden, ruleset);
                continue;
            }

            if (allowed is null || allowed.Any(pattern => Ruleset.Matches(package.Id, pattern)))
                continue;

            yield return new Violation(
                Id: "",
                Rule: Rule,
                Severity: ruleset.SeverityOf(Rule),
                Headline: $"{node.Name} declares {package.Id}",
                FromProject: node.Name,
                FromRing: node.Ring.ToString(),
                FromModule: node.File.Module,
                ToProject: package.Id,
                ToRing: "package",
                ToModule: null,
                Kind: "package",
                Path: [node.Name, package.Id],
                Evidence: package.Source,
                FixAt: package.Source,
                FixHint: allowed.Length == 0
                    ? $"{node.Ring} projects are allowed no packages at all. Move whatever needs "
                        + $"{package.Id} out of {node.Name}."
                    : $"{node.Ring} projects are allowed only: {string.Join(", ", allowed)}. Move "
                        + $"whatever needs {package.Id} to a ring that may hold it."
            );
        }
    }

    /// A package the ring is forbidden outright. Shared with the import reading, which reaches
    /// the same rule from a namespace instead of a declared id.
    public static Violation Refuse(
        ProjectNode node,
        string id,
        SourceSpan evidence,
        string pattern,
        Ruleset ruleset,
        string kind = "package"
    ) =>
        new(
            Id: "",
            Rule: ForbiddenRule,
            Severity: ruleset.SeverityOf(ForbiddenRule),
            Headline: kind.StartsWith("package import", StringComparison.Ordinal)
                ? $"{Path.GetFileName(evidence.File)} imports {id}, which {node.Ring} may never hold"
                : $"{node.Name} takes {id}, which {node.Ring} may never hold",
            FromProject: node.Name,
            FromRing: node.Ring.ToString(),
            FromModule: node.File.Module,
            ToProject: id,
            ToRing: "package",
            ToModule: null,
            Kind: kind,
            Path: [node.Name, id],
            Evidence: evidence,
            FixAt: evidence,
            FixHint: $"{node.Ring} may never hold a package matching `{pattern}`. Move whatever "
                + $"needs {id} to a ring that may."
        );
}
