using Microsoft.CodeAnalysis;
using Microsoft.CodeAnalysis.CSharp;

namespace LayerGuard;

/// Which source files belong to which project, and their parsed form. Parsing only — no
/// compilation, no restore — so every rule built on this answers on code that does not build.
public static class SourceFiles
{
    /// Every .cs file belongs to the nearest project above it, so a project nested inside
    /// another one keeps its own files instead of having them counted twice.
    public static Dictionary<string, List<string>> ByProject(IEnumerable<ProjectNode> nodes)
    {
        var directories = nodes.ToDictionary(
            node => node.FullPath,
            node => Path.GetDirectoryName(node.FullPath)!
        );
        var owners = directories.Keys.ToDictionary(projectPath => projectPath, _ => new List<string>());
        var deepestFirst = directories.OrderByDescending(pair => pair.Value.Length).ToList();

        foreach (var (projectPath, directory) in deepestFirst)
        {
            if (!Directory.Exists(directory))
                continue;

            foreach (var file in Directory.EnumerateFiles(directory, "*.cs", SearchOption.AllDirectories))
            {
                if (IsGenerated(file))
                    continue;

                var owner = deepestFirst.First(pair =>
                    file.StartsWith(pair.Value + Path.DirectorySeparatorChar, StringComparison.Ordinal)
                );
                if (owner.Key == projectPath)
                    owners[projectPath].Add(file);
            }
        }

        return owners;
    }

    public static SyntaxTree Parse(string file) => CSharpSyntaxTree.ParseText(File.ReadAllText(file));

    private static bool IsGenerated(string file) =>
        file.Split(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar)
            .Any(part => part is "obj" or "bin");
}
