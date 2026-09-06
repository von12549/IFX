using Microsoft.CodeAnalysis.CSharp.Syntax;

namespace LayerGuard;

/// Which rings declare a type of a given name. A rule like "implements an interface declared in
/// Domain" needs to look outside the file in front of it, so the whole codebase is read once
/// before any such rule is judged — and only when one is stated.
///
/// The key is the type's simple name: a base type written `Acme.Sales.IOrderRepository<Order>`
/// and a declaration written `IOrderRepository<T>` are the same contract, and nothing here
/// resolves a name to a symbol. Two types sharing a simple name in different rings both land
/// under that name, so a rule they both match passes on either.
public static class DeclarationIndex
{
    public static IReadOnlyDictionary<string, HashSet<Ring>> Build(
        IEnumerable<ProjectNode> nodes,
        IReadOnlyDictionary<string, List<string>> sources
    )
    {
        var index = new Dictionary<string, HashSet<Ring>>(StringComparer.Ordinal);

        foreach (var node in nodes)
        {
            if (!sources.TryGetValue(node.FullPath, out var files))
                continue;

            foreach (var file in files)
            {
                var root = SourceFiles.Parse(file).GetRoot();
                foreach (var declaration in root.DescendantNodes().OfType<BaseTypeDeclarationSyntax>())
                {
                    if (!index.TryGetValue(declaration.Identifier.Text, out var rings))
                        index[declaration.Identifier.Text] = rings = [];
                    rings.Add(node.Ring);
                }
            }
        }

        return index;
    }

    /// `Acme.Sales.IOrderRepository<Order>` and `IOrderRepository` are the same name here.
    public static string SimpleName(BaseTypeSyntax baseType)
    {
        var name = baseType.Type;
        while (name is QualifiedNameSyntax qualified)
            name = qualified.Right;

        // A generic name is a simple name, so `IRepository<T>` reduces to its identifier here
        // and needs no case of its own.
        return name is SimpleNameSyntax simple ? simple.Identifier.Text : name.ToString();
    }
}
