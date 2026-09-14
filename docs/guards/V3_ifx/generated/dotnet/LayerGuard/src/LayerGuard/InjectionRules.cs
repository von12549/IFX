using Microsoft.CodeAnalysis.CSharp.Syntax;

namespace LayerGuard;

/// What a type is handed. A project reference says a layer *can* see something and an import
/// says a file *names* it; a parameter says an instance was passed in, which is the difference
/// between an endpoint that asks a use case for an answer and one that reaches into storage
/// itself.
///
/// Two rules live here. One matches the name a parameter is written with; the other asks which
/// ring declared that name, which is what "never a concrete class from Infrastructure" says and
/// what no naming convention could state on its own.
///
/// Both ways a type is handed something are read. Constructor injection is the familiar one, but
/// a static endpoint class holding no state takes the same dependency as a method parameter, and
/// a rule blind to that form is blind to a whole style of writing the layer.
///
/// What a method body then does with the thing is not looked at, so this catches the dependency
/// and never the call.
public static class InjectionRules
{
    public const string Rule = "FORBIDDEN-DEPENDENCY";
    public const string OriginRule = "FORBIDDEN-DEPENDENCY-ORIGIN";

    public static IEnumerable<Violation> For(
        ProjectNode node,
        string file,
        Ruleset ruleset,
        IReadOnlyDictionary<string, HashSet<DeclarationSite>> index
    )
    {
        var byName = ruleset.ForbiddenDependencies.ContainsKey(node.Ring);
        ruleset.ForbiddenDependencyOrigins.TryGetValue(node.Ring, out var byOrigin);
        if (!byName && byOrigin is null)
            yield break;

        var tree = SourceFiles.Parse(file);

        foreach (var declaration in tree.GetRoot().DescendantNodes().OfType<TypeDeclarationSyntax>())
        {
            foreach (var parameter in Parameters(declaration))
            {
                if (parameter.Type is null)
                    continue;

                foreach (var name in TypeNames(parameter.Type))
                {
                    var pattern = byName ? ruleset.ForbidsDependency(node.Ring, name) : null;
                    var origin = pattern is null ? OriginOf(name, byOrigin, node.Ring, index) : null;
                    if (pattern is null && origin is null)
                        continue;

                    var line = tree.GetLineSpan(parameter.Span).StartLinePosition.Line + 1;
                    var evidence = new SourceSpan(file, line, parameter.ToString().Trim());

                    yield return new Violation(
                        Id: "",
                        Rule: pattern is null ? OriginRule : Rule,
                        Severity: ruleset.SeverityOf(pattern is null ? OriginRule : Rule),
                        Headline: $"{declaration.Identifier.Text} is handed {name}",
                        FromProject: node.Name,
                        FromRing: node.Ring.ToString(),
                        FromModule: node.Module,
                        ToProject: name,
                        ToRing: origin?.ToString() ?? "type",
                        ToModule: node.Module,
                        Kind: KindOf(parameter),
                        Path: [node.Name, declaration.Identifier.Text, name],
                        Evidence: evidence,
                        FixAt: evidence,
                        FixHint: pattern is not null
                            ? $"{node.Ring} types may not be handed `{pattern}`. Ask a layer that "
                                + $"may hold {name} for the answer, and let "
                                + $"{declaration.Identifier.Text} take that instead."
                            : $"{name} is declared in {origin}, and {node.Ring} may not be handed a "
                                + $"{origin} type. Take the contract {name} answers to instead, so "
                                + $"{declaration.Identifier.Text} names no {origin} type at all."
                    );
                    break;
                }
            }
        }
    }

    /// The ring a name was declared in, when the rule file forbids that ring and the ring being
    /// judged does not declare a type of the same name itself. Where it does, the name most
    /// likely binds to its own — a name is matched here, never resolved.
    private static Ring? OriginOf(
        string name,
        Ring[]? forbidden,
        Ring judged,
        IReadOnlyDictionary<string, HashSet<DeclarationSite>> index
    )
    {
        if (forbidden is null || !index.TryGetValue(name, out var declaredIn)
            || declaredIn.Any(site => site.Ring == judged))
            return null;

        foreach (var ring in forbidden)
        {
            if (declaredIn.Any(site => site.Ring == ring))
                return ring;
        }

        return null;
    }

    /// Every way this type is handed something: a primary constructor, a declared one, and a
    /// method parameter. The last is not a detour — a static class has no constructor to inject
    /// into, so its dependencies arrive on the method or not at all.
    private static IEnumerable<ParameterSyntax> Parameters(TypeDeclarationSyntax declaration)
    {
        foreach (var parameter in declaration.ParameterList?.Parameters ?? [])
            yield return parameter;

        foreach (var constructor in declaration.Members.OfType<ConstructorDeclarationSyntax>())
        {
            foreach (var parameter in constructor.ParameterList.Parameters)
                yield return parameter;
        }

        foreach (var method in declaration.Members.OfType<MethodDeclarationSyntax>())
        {
            foreach (var parameter in method.ParameterList.Parameters)
                yield return parameter;
        }
    }

    private static string KindOf(ParameterSyntax parameter) =>
        parameter.Parent?.Parent is MethodDeclarationSyntax ? "method parameter" : "constructor parameter";

    /// Every simple name written anywhere in a parameter's type, so `IUserRepository`,
    /// `IUserRepository?` and `IReadOnlyList<IUserRepository>` all offer the same name to match.
    /// A type is wrapped to be carried, not to stop being carried.
    private static IEnumerable<string> TypeNames(TypeSyntax type) =>
        type.DescendantNodesAndSelf().OfType<SimpleNameSyntax>().Select(name => name.Identifier.Text);
}
