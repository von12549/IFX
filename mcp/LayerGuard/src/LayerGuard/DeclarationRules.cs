using Microsoft.CodeAnalysis;
using Microsoft.CodeAnalysis.CSharp.Syntax;

namespace LayerGuard;

/// Where a kind of type has to be declared. The rule's whole input is the type's own name,
/// because a naming convention is the only thing a codebase states out loud about what a type is
/// for — a handler is a handler because somebody called it one.
///
/// A codebase with no declaration rules gets no findings here, and that is the honest default:
/// which names mean what is a convention, and conventions belong in the rule file, not in a tool.
public static class DeclarationRules
{
    public const string Rule = "DECLARATION-PLACEMENT";
    public const string ImplementsRule = "DECLARATION-IMPLEMENTS";

    public static IEnumerable<Violation> For(
        ProjectNode node,
        string file,
        Ruleset ruleset,
        IReadOnlyDictionary<string, HashSet<Ring>> index
    )
    {
        if (ruleset.Declarations.Count == 0)
            yield break;

        var tree = SourceFiles.Parse(file);

        foreach (var declaration in tree.GetRoot().DescendantNodes().OfType<BaseTypeDeclarationSyntax>())
        {
            var name = declaration.Identifier.Text;
            var kind = KindOf(declaration);

            foreach (var rule in ruleset.Declarations)
            {
                if (rule.Kind is not null && !rule.Kind.Equals(kind, StringComparison.OrdinalIgnoreCase))
                    continue;
                if (!Ruleset.Matches(name, rule.Match))
                    continue;

                var line = tree.GetLineSpan(declaration.Span).StartLinePosition.Line + 1;
                var evidence = new SourceSpan(file, line, Signature(declaration));

                if (rule.MustImplement is { } contractRing && !Implements(declaration, contractRing, index))
                    yield return Unimplemented(node, name, kind, contractRing, rule, evidence, ruleset);

                if (node.Ring == rule.MustLiveIn)
                    continue;

                yield return new Violation(
                    Id: "",
                    Rule: Rule,
                    Severity: rule.Severity ?? ruleset.SeverityOf(Rule),
                    Headline: $"{name} is declared in {node.Ring}, not {rule.MustLiveIn}",
                    FromProject: node.Name,
                    FromRing: node.Ring.ToString(),
                    FromModule: node.File.Module,
                    ToProject: name,
                    ToRing: rule.MustLiveIn.ToString(),
                    ToModule: node.File.Module,
                    Kind: "declaration",
                    Path: [node.Name, name],
                    Evidence: evidence,
                    FixAt: evidence,
                    FixHint: $"The rules place anything named `{rule.Match}` in {rule.MustLiveIn}. "
                        + $"Move {name} to the {rule.MustLiveIn} project of this module."
                );
            }
        }
    }

    /// True when the type names a base type the index places in the required ring. A type with
    /// no base list names nothing, and so satisfies no such rule.
    private static bool Implements(
        BaseTypeDeclarationSyntax declaration,
        Ring required,
        IReadOnlyDictionary<string, HashSet<Ring>> index
    ) =>
        declaration.BaseList is not null
        && declaration.BaseList.Types.Any(baseType =>
            index.TryGetValue(DeclarationIndex.SimpleName(baseType), out var rings) && rings.Contains(required)
        );

    private static Violation Unimplemented(
        ProjectNode node,
        string name,
        string kind,
        Ring required,
        DeclarationRule rule,
        SourceSpan evidence,
        Ruleset ruleset
    ) =>
        new(
            Id: "",
            Rule: ImplementsRule,
            Severity: rule.Severity ?? ruleset.SeverityOf(ImplementsRule),
            Headline: $"{name} implements nothing declared in {required}",
            FromProject: node.Name,
            FromRing: node.Ring.ToString(),
            FromModule: node.File.Module,
            ToProject: name,
            ToRing: required.ToString(),
            ToModule: node.File.Module,
            Kind: kind,
            Path: [node.Name, name],
            Evidence: evidence,
            FixAt: evidence,
            FixHint: $"The rules say anything named `{rule.Match}` answers to a contract declared "
                + $"in {required}. Declare the interface {name} implements in the {required} "
                + $"project of this module, and have {name} name it."
        );

    public static string KindOf(BaseTypeDeclarationSyntax declaration) =>
        declaration switch
        {
            ClassDeclarationSyntax => "class",
            InterfaceDeclarationSyntax => "interface",
            RecordDeclarationSyntax => "record",
            StructDeclarationSyntax => "struct",
            EnumDeclarationSyntax => "enum",
            _ => "type",
        };

    /// The declaration line without its body, so the report shows what was found and not a file.
    private static string Signature(BaseTypeDeclarationSyntax declaration)
    {
        var keyword = KindOf(declaration);
        var bases = declaration.BaseList is null ? "" : " : " + declaration.BaseList.Types.ToString();
        return $"{keyword} {declaration.Identifier.Text}{bases}";
    }
}
