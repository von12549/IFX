using LayerGuard;

namespace LayerGuard.Tests;

/// Every case is a real folder of project files under tests/fixtures, named for the situation
/// it holds. Open the folder named in a test and the case is in front of you; nothing here
/// builds a codebase on the fly.
internal static class Fixtures
{
    public const string DirectReference = "DirectReference";
    public const string DirectSiblingReference = "DirectSiblingReference";
    public const string IndirectReference = "IndirectReference";
    public const string IndirectSiblingReference = "IndirectSiblingReference";
    public const string IndirectKeptPrivate = "IndirectKeptPrivate";
    public const string IndirectSharedHop = "IndirectSharedHop";
    public const string AllowedDirections = "AllowedDirections";
    public const string DisableTransitive = "DisableTransitive";
    public const string PrivateAssetsAttributeForm = "PrivateAssetsAttributeForm";
    public const string CustomRules = "CustomRules";
    public const string ForbiddenPackages = "ForbiddenPackages";
    public const string AllowedReferences = "AllowedReferences";
    public const string Implements = "Implements";
    public const string ForbiddenDependencies = "ForbiddenDependencies";
    public const string DeclarationPlacement = "DeclarationPlacement";
    public const string Imports = "Imports";
    public const string Rulebook = "Rulebook";
    public const string SolutionScope = "SolutionScope";
    public const string BootstrapArchitecture = "BootstrapArchitecture";

    private static readonly string Root = Path.GetFullPath(
        Path.Combine(AppContext.BaseDirectory, "..", "..", "..", "..", "fixtures")
    );

    public static string PathTo(string fixture) => Path.Combine(Root, fixture);

    public static string ProjectFile(string fixture, string project) =>
        Path.Combine(PathTo(fixture), project, project + ".csproj");

    public static Report Check(string fixture) => Analyzer.Analyze(PathTo(fixture), configPath: null);

    public static Violation Between(this Report report, string from, string to) =>
        report.Violations.Single(violation => violation.FromRing == from && violation.ToRing == to);

    /// Layers and reference counts, with project names dropped, so two fixtures built to the
    /// same shape can be compared even though their projects are named differently.
    public static string[] Shape(this Report report) =>
        report
            .Projects.Concat(report.Outside)
            .Select(project => $"{project.Ring}:{project.DirectProjectReferences}")
            .Order()
            .ToArray();
}
