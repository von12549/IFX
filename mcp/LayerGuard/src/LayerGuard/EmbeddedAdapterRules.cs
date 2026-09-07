using Microsoft.CodeAnalysis;
using Microsoft.CodeAnalysis.CSharp.Syntax;

namespace LayerGuard;

/// Allows a physical Infrastructure project to host adapters without granting its other
/// namespaces permission to consume foreign Contracts.
public static class EmbeddedAdapterRules
{
    public const string LocationRule = "EMBEDDED-ADAPTER-LOCATION";
    public const string ProviderRule = "EMBEDDED-ADAPTER-PROVIDER";

    public static IEnumerable<Violation> For(
        ProjectNode node,
        string file,
        IReadOnlyList<ProjectNode> projects,
        Ruleset ruleset
    )
    {
        if (node.Ring != Ring.Infrastructure || node.Module is null)
            yield break;

        var tree = SourceFiles.Parse(file);
        var root = tree.GetRoot();
        foreach (var name in root.DescendantNodes().OfType<NameSyntax>())
        {
            var targetText = name.ToString();
            var target = ImportRules.DeclaringProject(targetText, projects);
            if (target is null || target.Ring != Ring.Contracts || target.Module is null
                || string.Equals(node.Module, target.Module, StringComparison.OrdinalIgnoreCase))
                continue;
            if (name.Parent is NameSyntax parent && parent.ToString().Contains(targetText, StringComparison.Ordinal))
                continue;

            var containingNamespace = name.Ancestors().OfType<BaseNamespaceDeclarationSyntax>()
                .FirstOrDefault()?.Name.ToString() ?? RootNamespace(root);
            var evidence = new SourceSpan(
                file,
                tree.GetLineSpan(name.Span).StartLinePosition.Line + 1,
                targetText
            );

            if (!ruleset.EmbeddedAdapterNamespaces.Any(pattern => Ruleset.Matches(containingNamespace, pattern)))
                yield return Finding(
                    LocationRule,
                    node,
                    target,
                    evidence,
                    $"Move this foreign Contracts use under an approved embedded adapter namespace: {string.Join(", ", ruleset.EmbeddedAdapterNamespaces)}."
                );
            if (!ruleset.IsApprovedProvider(node.Module, target.Module))
                yield return Finding(
                    ProviderRule,
                    node,
                    target,
                    evidence,
                    $"Register provider `{target.Module}` for consumer `{node.Module}`, or remove this Contracts use."
                );
        }
    }

    private static string RootNamespace(SyntaxNode root) =>
        root.DescendantNodes().OfType<BaseNamespaceDeclarationSyntax>().FirstOrDefault()?.Name.ToString() ?? "";

    private static Violation Finding(
        string rule,
        ProjectNode node,
        ProjectNode target,
        SourceSpan evidence,
        string hint
    ) => new(
        "",
        rule,
        Ruleset.Breaks,
        $"{node.Name} uses foreign Contracts from {target.Name} outside its adapter boundary",
        node.Name,
        node.Ring.ToString(),
        node.Module,
        target.Name,
        target.Ring.ToString(),
        target.Module,
        "foreign Contracts source use",
        [node.Name, target.Name],
        evidence,
        evidence,
        hint
    );
}
