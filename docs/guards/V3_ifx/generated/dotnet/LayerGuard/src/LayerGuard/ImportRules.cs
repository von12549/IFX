using Microsoft.CodeAnalysis;
using Microsoft.CodeAnalysis.CSharp;
using Microsoft.CodeAnalysis.CSharp.Syntax;

namespace LayerGuard;

/// The same rules, read off the source files instead of the project files. A reference says a
/// layer *can* see something; an import says a file *does*. Both matter and neither replaces the
/// other: a reference nothing imports is a boundary already lost, and an import is where somebody
/// walked through it.
///
/// A namespace is matched against the names of the projects the run loaded. One that matches
/// none of them came from a package or from code outside the scope, and is judged against the
/// ring's package rule if it has one.
public static class ImportRules
{
    public const string DirectionRule = "IMPORT-DIRECTION";
    public const string PackageRule = "RING-PACKAGE-IMPORT";

    public static IEnumerable<Violation> For(
        ProjectNode node,
        string file,
        IReadOnlyList<ProjectNode> byLongestName,
        Ruleset ruleset
    )
    {
        var tree = SourceFiles.Parse(file);
        var root = tree.GetRoot();

        foreach (var directive in root.DescendantNodes().OfType<UsingDirectiveSyntax>())
        {
            var line = tree.GetLineSpan(directive.Span).StartLinePosition.Line + 1;
            var violation = Judge(node, directive, file, line, inactive: false, byLongestName, ruleset);
            if (violation is not null)
                yield return violation;
        }

        // A branch the preprocessor turned off never reaches the tree at all, so an import inside
        // one would be neither reported nor mentioned. Parse those regions on their own: the
        // import is real in whatever configuration turns that branch on.
        foreach (var region in root.DescendantTrivia().Where(t => t.IsKind(SyntaxKind.DisabledTextTrivia)))
        {
            var regionStart = tree.GetLineSpan(region.Span).StartLinePosition.Line;
            var fragment = CSharpSyntaxTree.ParseText(region.ToFullString());

            foreach (var directive in fragment.GetRoot().DescendantNodes().OfType<UsingDirectiveSyntax>())
            {
                var within = fragment.GetLineSpan(directive.Span).StartLinePosition.Line;
                var violation = Judge(
                    node,
                    directive,
                    file,
                    regionStart + within + 1,
                    inactive: true,
                    byLongestName,
                    ruleset
                );
                if (violation is not null)
                    yield return violation;
            }
        }
    }

    /// The project whose name is the longest prefix of this namespace, or null when no project
    /// in the run declares it.
    public static ProjectNode? DeclaringProject(string target, IReadOnlyList<ProjectNode> byLongestName) =>
        byLongestName.FirstOrDefault(candidate =>
            target == candidate.Name || target.StartsWith(candidate.Name + ".", StringComparison.Ordinal)
        );

    public static bool IsFrameworkNamespace(string target) =>
        target == "System" || target.StartsWith("System.", StringComparison.Ordinal);

    private static Violation? Judge(
        ProjectNode node,
        UsingDirectiveSyntax directive,
        string file,
        int line,
        bool inactive,
        IReadOnlyList<ProjectNode> byLongestName,
        Ruleset ruleset
    )
    {
        var target = directive.NamespaceOrType?.ToString();
        if (target is null || IsFrameworkNamespace(target))
            return null;

        var evidence = new SourceSpan(file, line, directive.ToString().Trim());
        var note = inactive ? " in a branch the preprocessor had turned off" : "";
        var declaring = DeclaringProject(target, byLongestName);

        if (declaring is null)
            return OutsideImport(node, target, evidence, note, ruleset);

        // A project the run loaded is a project, whatever ring it landed in. One that matches no
        // ring is outside the check — listed, never ruled on — and calling its namespace a
        // package would rule on it through the back door, under a rule meant for libraries.
        if (!declaring.InScope || declaring.FullPath == node.FullPath)
            return null;

        if (ruleset.IsSharedPrimitiveReference(node, declaring.Name))
            return null;

        if (ruleset.Allows(node.Ring, declaring.Ring)
            && ruleset.AllowsOwnership(node.Ring, declaring.Ring, node.Module, declaring.Module))
            return null;

        var ownershipOnly = ruleset.Allows(node.Ring, declaring.Ring);

        return new Violation(
            Id: "",
            Rule: ownershipOnly ? OwnershipRules.ScopeRule : DirectionRule,
            Severity: ruleset.SeverityOf(ownershipOnly ? OwnershipRules.ScopeRule : DirectionRule),
            Headline: $"{Path.GetFileName(file)} imports {declaring.Name}",
            FromProject: node.Name,
            FromRing: node.Ring.ToString(),
            FromModule: node.Module,
            ToProject: declaring.Name,
            ToRing: declaring.Ring.ToString(),
            ToModule: declaring.Module,
            Kind: "import" + note,
            Path: [node.Name, declaring.Name],
            Evidence: evidence,
            FixAt: evidence,
            FixHint: ownershipOnly
                ? $"Remove this import: {node.Ring} may not use {declaring.Ring} from module {declaring.Module}."
                : inactive
                ? $"Remove this import from {Path.GetFileName(file)}. It only compiles in the "
                    + $"configuration that turns this branch on, and there {node.Ring} depends on {declaring.Ring}."
                : $"Remove this import from {Path.GetFileName(file)}, along with the use of "
                    + $"{declaring.Name} that needs it."
        );
    }

    /// A namespace no project in scope declares. If the ring states which packages it may hold,
    /// the import is judged against that list — this is how a database library reaches a report
    /// at all, since a package carries no ring for the direction table to refuse.
    private static Violation? OutsideImport(
        ProjectNode node,
        string target,
        SourceSpan evidence,
        string note,
        Ruleset ruleset
    )
    {
        var forbidden = ruleset.ForbidsPackage(node.Ring, target);
        if (forbidden is not null)
            return PackageRules.Refuse(node, target, evidence, forbidden, ruleset, "package import" + note);

        var allowed = ruleset.PackagesAllowedIn(node.Ring);
        if (allowed is null || allowed.Any(pattern => Ruleset.Matches(target, pattern)))
            return null;

        return new Violation(
            Id: "",
            Rule: PackageRule,
            Severity: ruleset.SeverityOf(PackageRule),
            Headline: $"{Path.GetFileName(evidence.File)} imports {target}",
            FromProject: node.Name,
            FromRing: node.Ring.ToString(),
            FromModule: node.Module,
            ToProject: target,
            ToRing: "package",
            ToModule: null,
            Kind: "package import" + note,
            Path: [node.Name, target],
            Evidence: evidence,
            FixAt: evidence,
            FixHint: allowed.Length == 0
                ? $"{node.Ring} files may import nothing outside the codebase. Move whatever needs "
                    + $"{target} to a ring that may hold it."
                : $"{node.Ring} is allowed only: {string.Join(", ", allowed)}. Move whatever needs "
                    + $"{target} to a ring that may hold it."
        );
    }
}
