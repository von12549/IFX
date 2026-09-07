using Microsoft.CodeAnalysis;
using Microsoft.CodeAnalysis.CSharp.Syntax;

namespace LayerGuard;

/// Declaration and forbidden-type checks that do not require Gate-owned catalog data.
public static class SourcePolicyRules
{
    public const string NamespaceRuleId = "DECLARATION-NAMESPACE";
    public const string ForbiddenDeclarationRuleId = "DECLARATION-FORBIDDEN";
    public const string ForbiddenSymbolRuleId = "SYMBOL-FORBIDDEN";
    public const string PayloadRuleId = "PAYLOAD-TYPE-FORBIDDEN";

    public static IEnumerable<Violation> For(
        ProjectNode node,
        string file,
        Ruleset ruleset,
        IReadOnlyDictionary<string, HashSet<DeclarationSite>> declarationIndex
    )
    {
        var tree = SourceFiles.Parse(file);
        var root = tree.GetRoot();

        foreach (var declaration in root.DescendantNodes().OfType<BaseTypeDeclarationSyntax>())
        {
            var name = declaration.Identifier.Text;
            var kind = DeclarationRules.KindOf(declaration);
            var evidence = Span(tree, file, declaration, $"{kind} {name}");
            var declaredNamespace = NamespaceOf(declaration);

            foreach (var rule in ruleset.DeclarationNamespaces)
            {
                if (!Applies(name, kind, rule.Match, rule.Kind, rule.Exceptions))
                    continue;
                var implementsRequired = rule.MustImplement is null
                    || Implements(
                        declaration,
                        rule.MustImplement.Value,
                        rule.MustImplementOwn ? node.Module : null,
                        declarationIndex
                    );
                if (rule.MustLiveIn.Contains(node.Ring)
                    && Ruleset.Matches(declaredNamespace, rule.Namespace)
                    && implementsRequired)
                    continue;

                yield return Finding(
                    NamespaceRuleId,
                    node,
                    name,
                    string.Join(" or ", rule.MustLiveIn),
                    "declaration namespace",
                    evidence,
                    $"Move {name} to role {string.Join(" or ", rule.MustLiveIn)} under namespace `{rule.Namespace}`"
                        + (rule.MustImplement is null ? "." : $" and implement a Port declared in {rule.MustImplement}.")
                );
                break;
            }

            foreach (var rule in ruleset.ForbiddenDeclarations)
            {
                if (node.Ring != rule.In || !Applies(name, kind, rule.Match, rule.Kind, rule.Exceptions))
                    continue;
                yield return Finding(
                    ForbiddenDeclarationRuleId,
                    node,
                    name,
                    rule.In.ToString(),
                    "forbidden declaration",
                    evidence,
                    $"{rule.In} may not declare `{rule.Match}`. Move the implementation to an outer role or rename only if the type is genuinely not that responsibility."
                );
                break;
            }

            foreach (var payload in ruleset.Payloads)
            {
                if (!Ruleset.Matches(name, payload.Match) || IsException(name, payload.Exceptions))
                    continue;
                foreach (var type in PayloadTypes(declaration))
                {
                    var text = type.ToString();
                    var forbidden = payload.ForbiddenTypes?.FirstOrDefault(pattern =>
                        Ruleset.Matches(text, pattern) || Ruleset.Matches(Simple(text), pattern)
                    );
                    var offAllowList = payload.AllowedTypes is not null
                        && !payload.AllowedTypes.Any(pattern =>
                            Ruleset.Matches(text, pattern) || Ruleset.Matches(Simple(text), pattern)
                        );
                    if (forbidden is not null || offAllowList)
                        yield return Finding(
                            PayloadRuleId,
                            node,
                            text,
                            Ring.Contracts.ToString(),
                            "contract payload type",
                            Span(tree, file, type, text),
                            forbidden is not null
                                ? $"Payload `{name}` may not expose `{forbidden}`. Map it to a Contracts-owned BCL-only DTO."
                                : $"Payload `{name}` may use only: {string.Join(", ", payload.AllowedTypes!)}."
                        );
                }
            }
        }

        foreach (var finding in ForbiddenSource(node, file, tree, root, ruleset))
            yield return finding;
    }

    private static IEnumerable<Violation> ForbiddenSource(
        ProjectNode node,
        string file,
        SyntaxTree tree,
        SyntaxNode root,
        Ruleset ruleset
    )
    {
        ruleset.ForbiddenNamespaces.TryGetValue(node.Ring, out var namespacePatterns);
        foreach (var directive in root.DescendantNodes().OfType<UsingDirectiveSyntax>())
        {
            var target = directive.NamespaceOrType?.ToString();
            var forbidden = target is null
                ? null
                : namespacePatterns?.FirstOrDefault(pattern => Ruleset.Matches(target, pattern));
            if (forbidden is null)
                continue;
            yield return Forbidden(node, file, tree, directive, target!, forbidden);
        }

        ruleset.ForbiddenSymbols.TryGetValue(node.Ring, out var symbolPatterns);
        if (symbolPatterns is not null)
        {
            foreach (var expression in root.DescendantNodes().OfType<NameSyntax>())
            {
                var text = expression.ToString();
                var forbidden = symbolPatterns.FirstOrDefault(pattern =>
                    Ruleset.Matches(text, pattern) || Ruleset.Matches(Simple(text), pattern)
                );
                if (forbidden is null)
                    continue;
                // Report the outermost name once instead of every segment of a qualified name.
                if (expression.Parent is NameSyntax parent && parent.ToString().Contains(text, StringComparison.Ordinal))
                    continue;
                yield return Forbidden(node, file, tree, expression, text, forbidden);
            }
        }

        ruleset.ForbiddenText.TryGetValue(node.Ring, out var textPatterns);
        if (textPatterns is null)
            yield break;
        foreach (var literal in root.DescendantNodes().OfType<LiteralExpressionSyntax>())
        {
            var value = literal.Token.ValueText;
            var forbidden = textPatterns.FirstOrDefault(pattern => Ruleset.Matches(value, pattern));
            if (forbidden is not null)
                yield return Forbidden(node, file, tree, literal, value, forbidden);
        }
    }

    private static Violation Forbidden(
        ProjectNode node,
        string file,
        SyntaxTree tree,
        SyntaxNode syntax,
        string text,
        string pattern
    ) => Finding(
        ForbiddenSymbolRuleId,
        node,
        text,
        "forbidden",
        "source symbol",
        Span(tree, file, syntax, text),
        $"{node.Ring} may not reference `{pattern}`. Move runtime/framework code to an allowed outer role."
    );

    private static IEnumerable<TypeSyntax> PayloadTypes(BaseTypeDeclarationSyntax declaration) =>
        declaration.DescendantNodes().OfType<TypeSyntax>().Where(type =>
            type.Parent is ParameterSyntax or PropertyDeclarationSyntax or FieldDeclarationSyntax
        );

    private static bool Implements(
        BaseTypeDeclarationSyntax declaration,
        Ring required,
        string? requiredModule,
        IReadOnlyDictionary<string, HashSet<DeclarationSite>> index
    ) => declaration.BaseList is not null
        && declaration.BaseList.Types.Any(baseType =>
            index.TryGetValue(DeclarationIndex.SimpleName(baseType), out var sites)
            && sites.Any(site => site.Ring == required
                && (requiredModule is null
                    || string.Equals(site.Module, requiredModule, StringComparison.OrdinalIgnoreCase)))
        );

    private static bool Applies(
        string name,
        string kind,
        string match,
        string? requiredKind,
        string[]? exceptions
    ) =>
        Ruleset.Matches(name, match)
        && (requiredKind is null || requiredKind.Equals(kind, StringComparison.OrdinalIgnoreCase))
        && !IsException(name, exceptions);

    private static bool IsException(string name, string[]? exceptions) =>
        exceptions?.Any(pattern => Ruleset.Matches(name, pattern)) == true;

    private static string NamespaceOf(SyntaxNode declaration) =>
        declaration.Ancestors().OfType<BaseNamespaceDeclarationSyntax>().FirstOrDefault()?.Name.ToString() ?? "";

    private static string Simple(string name) => name.Split('.').Last().Split('<')[0].TrimEnd('?');

    private static SourceSpan Span(SyntaxTree tree, string file, SyntaxNode node, string text) =>
        new(file, tree.GetLineSpan(node.Span).StartLinePosition.Line + 1, text);

    private static Violation Finding(
        string rule,
        ProjectNode node,
        string target,
        string targetRole,
        string kind,
        SourceSpan evidence,
        string hint
    ) => new(
        "",
        rule,
        Ruleset.Breaks,
        $"{node.Name} contains {kind}: {target}",
        node.Name,
        node.Ring.ToString(),
        node.Module,
        target,
        targetRole,
        node.Module,
        kind,
        [node.Name, target],
        evidence,
        evidence,
        hint
    );
}
