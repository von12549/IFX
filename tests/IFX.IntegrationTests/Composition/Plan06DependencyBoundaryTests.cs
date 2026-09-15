using System.Xml.Linq;

namespace IFX.IntegrationTests.Composition;

public sealed class Plan06DependencyBoundaryTests
{
    [Fact]
    public void Module_infrastructure_integrations_are_grouped_by_direction()
    {
        var modules = Path.Combine(RepositoryRoot(), "src", "Modules");
        var violations = new List<string>();

        foreach (var moduleDirectory in Directory.EnumerateDirectories(modules))
        {
            var module = Path.GetFileName(moduleDirectory);
            var integrations = Path.Combine(moduleDirectory, $"IFX.Modules.{module}.Infrastructure", "Integrations");
            if (!Directory.Exists(integrations)) continue;

            foreach (var sourcePath in Directory.EnumerateFiles(integrations, "*.cs", SearchOption.AllDirectories))
            {
                var relative = Path.GetRelativePath(integrations, sourcePath);
                var direction = relative.Split(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar)[0];
                if (direction is not ("Inbound" or "Outbound"))
                {
                    violations.Add($"{module}: {relative} is not under Inbound or Outbound");
                    continue;
                }

                var expectedNamespace = $"IFX.Modules.{module}.Infrastructure.Integrations.{direction}";
                if (!File.ReadAllText(sourcePath).Contains($"namespace {expectedNamespace}", StringComparison.Ordinal))
                    violations.Add($"{module}: {relative} does not use {expectedNamespace}");
            }
        }

        violations.Should().BeEmpty();
    }

    [Fact]
    public void Retired_auth_project_tree_is_absent_and_unreferenced()
    {
        var repository = RepositoryRoot();
        var retiredRoot = Path.Combine(repository, "src", "Modules", "Auth");
        Directory.Exists(retiredRoot).Should().BeFalse();

        File.ReadAllText(Path.Combine(repository, "IFX.sln"))
            .Should().NotContain("Modules\\Auth", "the solution uses the renamed IAM projects");

        var references = Directory.EnumerateFiles(repository, "*.csproj", SearchOption.AllDirectories)
            .Where(path => !path.Split(Path.DirectorySeparatorChar).Any(part => part is "bin" or "obj"))
            .SelectMany(project => XDocument.Load(project).Descendants("ProjectReference")
                .Select(reference => new
                {
                    Project = Path.GetRelativePath(repository, project),
                    Include = (string?)reference.Attribute("Include")
                }))
            .Where(reference => reference.Include?.Contains("IFX.Modules.Auth", StringComparison.Ordinal) == true)
            .Select(reference => $"{reference.Project} -> {reference.Include}")
            .ToArray();

        references.Should().BeEmpty();
    }

    [Fact]
    public void Module_application_and_domain_projects_do_not_reference_module_public_contracts()
    {
        var modules = Path.Combine(RepositoryRoot(), "src", "Modules");
        var violations = new List<string>();

        foreach (var moduleDirectory in Directory.EnumerateDirectories(modules))
        {
            var module = Path.GetFileName(moduleDirectory);
            foreach (var ring in new[] { "Application", "Domain" })
            {
                var projectDirectory = Path.Combine(moduleDirectory, $"IFX.Modules.{module}.{ring}");
                var projectPath = Path.Combine(projectDirectory, $"IFX.Modules.{module}.{ring}.csproj");
                if (!File.Exists(projectPath)) continue;

                var references = XDocument.Load(projectPath).Descendants("ProjectReference")
                    .Select(element => (string?)element.Attribute("Include"))
                    .Where(value => value is not null);
                if (references.Any(value => value!.Contains($"IFX.Modules.{module}.Contracts.csproj", StringComparison.Ordinal)))
                    violations.Add($"{module}.{ring} project reference");

                foreach (var sourcePath in Directory.EnumerateFiles(projectDirectory, "*.cs", SearchOption.AllDirectories)
                             .Where(path => !path.Split(Path.DirectorySeparatorChar)
                                 .Any(part => part is "bin" or "obj")))
                {
                    if (File.ReadAllText(sourcePath).Contains($"IFX.Modules.{module}.Contracts", StringComparison.Ordinal))
                        violations.Add(Path.GetRelativePath(modules, sourcePath));
                }
            }
        }

        violations.Should().BeEmpty();
    }

    private static string RepositoryRoot()
    {
        var directory = new DirectoryInfo(AppContext.BaseDirectory);
        while (directory is not null && !File.Exists(Path.Combine(directory.FullName, "IFX.sln")))
            directory = directory.Parent;
        return directory?.FullName ?? throw new InvalidOperationException("Repository root not found.");
    }
}
