using System.Text.RegularExpressions;
using System.Xml.Linq;

namespace IFX.IntegrationTests.Composition;

public sealed class Plan07DependencyBoundaryTests
{
    private static readonly string[] ConsumerModules = ["CRM", "Registry", "Holdings", "Transaction"];

    [Fact]
    public void Context_runtime_and_iam_client_have_closed_project_dependencies()
    {
        var repository = RepositoryRoot();
        var runtime = Path.Combine(
            repository,
            "src", "Platform", "Context", "IFX.Platform.Context.Runtime", "IFX.Platform.Context.Runtime.csproj");
        var client = Path.Combine(
            repository,
            "src", "Modules", "IAM", "IFX.Modules.IAM.Client", "IFX.Modules.IAM.Client.csproj");

        ProjectReferenceNames(runtime).Should().BeEquivalentTo(
            "IFX.Platform.Context.Contracts",
            "IFX.BuildingBlocks.Application");
        ProjectReferenceNames(client).Should().BeEquivalentTo(
            "IFX.Modules.IAM.Contracts",
            "IFX.Platform.Context.Runtime",
            "IFX.BuildingBlocks.Security");
    }

    [Fact]
    public void Only_infrastructure_and_composition_projects_reference_iam_client()
    {
        var source = Path.Combine(RepositoryRoot(), "src");
        var violations = Directory.EnumerateFiles(source, "*.csproj", SearchOption.AllDirectories)
            .Where(project => ProjectReferenceNames(project).Contains("IFX.Modules.IAM.Client"))
            .Where(project =>
            {
                var name = Path.GetFileNameWithoutExtension(project);
                return !name.EndsWith(".Infrastructure", StringComparison.Ordinal)
                    && !name.EndsWith(".Composition", StringComparison.Ordinal);
            })
            .Select(project => Path.GetRelativePath(source, project))
            .ToArray();

        violations.Should().BeEmpty();
    }

    [Fact]
    public void Module_application_and_domain_do_not_reference_outer_adapter_dependencies()
    {
        var modules = Path.Combine(RepositoryRoot(), "src", "Modules");
        var violations = new List<string>();

        foreach (var project in Directory.EnumerateFiles(modules, "*.csproj", SearchOption.AllDirectories)
                     .Where(path => Regex.IsMatch(
                         Path.GetFileNameWithoutExtension(path),
                         @"^IFX\.Modules\.[^.]+\.(Application|Domain)$")))
        {
            var projectName = Path.GetFileNameWithoutExtension(project);
            foreach (var reference in ProjectReferenceNames(project))
            {
                if (Regex.IsMatch(reference, @"^IFX\.Modules\.[^.]+\.(Contracts|Client|Infrastructure)$")
                    || Regex.IsMatch(reference, @"^IFX\.Platform\.[^.]+\.Runtime$"))
                    violations.Add($"{projectName} -> {reference}");
            }

            var projectDirectory = Path.GetDirectoryName(project)!;
            foreach (var sourcePath in SourceFiles(projectDirectory))
            {
                var sourceText = File.ReadAllText(sourcePath);
                if (Regex.IsMatch(sourceText, @"IFX\.Modules\.[^.]+\.(Contracts|Client|Infrastructure)")
                    || Regex.IsMatch(sourceText, @"IFX\.Platform\.[^.]+\.Runtime"))
                    violations.Add(Path.GetRelativePath(modules, sourcePath));
            }
        }

        violations.Should().BeEmpty();
    }

    [Fact]
    public void Module_contract_adapters_do_not_construct_protocol_or_provider_contexts_directly()
    {
        var modules = Path.Combine(RepositoryRoot(), "src", "Modules");
        var violations = Directory.EnumerateFiles(modules, "*.cs", SearchOption.AllDirectories)
            .Where(path => path.Contains(
                $"{Path.DirectorySeparatorChar}Infrastructure{Path.DirectorySeparatorChar}Integrations{Path.DirectorySeparatorChar}",
                StringComparison.Ordinal))
            .Where(path =>
            {
                var source = File.ReadAllText(path);
                return source.Contains("new ContractRequestContext", StringComparison.Ordinal)
                    || source.Contains("new ExecutionContextSnapshot", StringComparison.Ordinal);
            })
            .Select(path => Path.GetRelativePath(modules, path))
            .ToArray();

        violations.Should().BeEmpty();
    }

    [Fact]
    public void Iam_outbound_adapters_preserve_module_ports_and_fixed_identity_seams()
    {
        var repository = RepositoryRoot();
        var violations = new List<string>();

        foreach (var module in ConsumerModules)
        {
            var infrastructure = Path.Combine(
                repository, "src", "Modules", module, $"IFX.Modules.{module}.Infrastructure");
            var adapter = Path.Combine(
                infrastructure, "Integrations", "Outbound", "IAM", "ResourceAuthorizationAdapter.cs");
            var source = File.ReadAllText(adapter);

            if (!source.Contains(": IResourceAuthorizationService", StringComparison.Ordinal))
                violations.Add($"{module}: adapter does not implement its Application port");
            if (!source.Contains("IamResourceAuthorizationClient", StringComparison.Ordinal))
                violations.Add($"{module}: adapter does not delegate to the provider client");
            if (!source.Contains("ContractComponentIdentity", StringComparison.Ordinal)
                && !source.Contains("TransactionContractConsumer.Identity", StringComparison.Ordinal))
                violations.Add($"{module}: adapter has no fixed consumer identity seam");

            var dependencies = ProjectReferenceNames(Path.Combine(
                infrastructure, $"IFX.Modules.{module}.Infrastructure.csproj"));
            if (!dependencies.Contains("IFX.Modules.IAM.Client"))
                violations.Add($"{module}: Infrastructure does not reference IAM.Client");
            if (dependencies.Contains("IFX.Modules.IAM.Contracts"))
                violations.Add($"{module}: Infrastructure bypasses IAM.Client");

            var registrations = Regex.Matches(
                File.ReadAllText(Path.Combine(infrastructure, "DependencyInjection.cs")),
                @"AddScoped<IResourceAuthorizationService,\s*ResourceAuthorizationAdapter>").Count;
            if (registrations != 1)
                violations.Add($"{module}: expected one Application port registration, found {registrations}");
        }

        violations.Should().BeEmpty();
    }

    private static string[] ProjectReferenceNames(string projectPath) =>
        XDocument.Load(projectPath).Descendants("ProjectReference")
            .Select(reference => (string?)reference.Attribute("Include"))
            .Where(include => !string.IsNullOrWhiteSpace(include))
            .Select(include => Path.GetFileNameWithoutExtension(include!))
            .ToArray();

    private static IEnumerable<string> SourceFiles(string directory) =>
        Directory.EnumerateFiles(directory, "*.cs", SearchOption.AllDirectories)
            .Where(path => !path.Split(Path.DirectorySeparatorChar).Any(part => part is "bin" or "obj"));

    private static string RepositoryRoot()
    {
        var directory = new DirectoryInfo(AppContext.BaseDirectory);
        while (directory is not null && !File.Exists(Path.Combine(directory.FullName, "IFX.sln")))
            directory = directory.Parent;
        return directory?.FullName ?? throw new InvalidOperationException("Repository root not found.");
    }
}
