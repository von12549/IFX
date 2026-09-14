using System.Xml;
using System.Xml.Linq;

namespace LayerGuard;

/// Reads one project file. Element names are matched by local name so a project that
/// carries the old MSBuild namespace parses the same as an SDK-style one.
public static class CsprojReader
{
    public static ProjectFile Read(string csprojPath)
    {
        var fullPath = Paths.Normalize(csprojPath);
        var projectDir = Path.GetDirectoryName(fullPath)!;
        var document = XDocument.Load(fullPath, LoadOptions.SetLineInfo);
        var root = document.Root ?? throw new InvalidDataException($"{fullPath} has no root element");

        var projectReferences = new List<ProjectReferenceEntry>();
        var packageReferences = new List<PackageReferenceEntry>();
        var frameworkReferences = new List<string>();

        foreach (var element in root.Descendants())
        {
            var include = element.Attribute("Include")?.Value;
            switch (element.Name.LocalName)
            {
                case "ProjectReference" when include is not null:
                    projectReferences.Add(
                        new ProjectReferenceEntry(
                            Paths.Normalize(Path.Combine(projectDir, ToPlatformPath(include))),
                            include,
                            StopsTransitiveFlow(element),
                            SpanOf(fullPath, element)
                        )
                    );
                    break;

                case "PackageReference" when include is not null:
                    packageReferences.Add(
                        new PackageReferenceEntry(
                            include,
                            element.Attribute("Version")?.Value ?? ChildValue(element, "Version"),
                            StopsTransitiveFlow(element),
                            SpanOf(fullPath, element)
                        )
                    );
                    break;

                case "FrameworkReference" when include is not null:
                    frameworkReferences.Add(include);
                    break;
            }
        }

        return new ProjectFile(
            FullPath: fullPath,
            Name: Path.GetFileNameWithoutExtension(fullPath),
            Sdk: root.Attribute("Sdk")?.Value ?? "",
            Module: ModuleOf(projectDir),
            TransitiveReferencesDisabled: IsTrue(FindProperty(root, "DisableTransitiveProjectReferences")),
            ProjectReferences: projectReferences,
            PackageReferences: packageReferences,
            FrameworkReferences: frameworkReferences
        );
    }

    /// `PrivateAssets` may be an attribute or a child element, and the child form is the one
    /// that a single-line attribute reader silently misses.
    private static bool StopsTransitiveFlow(XElement element)
    {
        var value = element.Attribute("PrivateAssets")?.Value ?? ChildValue(element, "PrivateAssets");
        if (string.IsNullOrWhiteSpace(value))
            return false;

        var parts = value.Split([';', ','], StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries);
        return parts.Any(part =>
            part.Equals("all", StringComparison.OrdinalIgnoreCase)
            || part.Equals("compile", StringComparison.OrdinalIgnoreCase)
        );
    }

    private static string? ChildValue(XElement element, string localName) =>
        element.Elements().FirstOrDefault(child => child.Name.LocalName == localName)?.Value.Trim();

    private static string? FindProperty(XElement root, string localName) =>
        root.Descendants()
            .FirstOrDefault(element => element.Name.LocalName == localName && element.Parent?.Name.LocalName == "PropertyGroup")
            ?.Value.Trim();

    private static bool IsTrue(string? value) => value?.Equals("true", StringComparison.OrdinalIgnoreCase) == true;

    /// The folder holding the project folder. In a modular layout that is the module name;
    /// it is reported, never judged.
    private static string? ModuleOf(string projectDir) =>
        Path.GetFileName(Path.GetDirectoryName(projectDir) ?? "") is { Length: > 0 } name ? name : null;

    private static string ToPlatformPath(string include) =>
        include.Replace('\\', Path.DirectorySeparatorChar).Replace('/', Path.DirectorySeparatorChar);

    private static SourceSpan SpanOf(string file, XElement element)
    {
        var line = element is IXmlLineInfo info && info.HasLineInfo() ? info.LineNumber : 0;
        var text = element.ToString().Split('\n')[0].Trim();
        return new SourceSpan(file, line, text);
    }
}
