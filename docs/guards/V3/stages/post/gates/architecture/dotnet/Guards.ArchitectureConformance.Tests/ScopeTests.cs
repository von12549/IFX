using LayerGuard;
using Xunit;

namespace LayerGuard.Tests;

/// What the path handed in decides. tests/fixtures/SolutionScope holds three projects on disk
/// and a solution file listing two of them, so the same folder gives two different scopes
/// depending on which one is named.
public class ScopeTests
{
    [Fact]
    public void A_solution_file_checks_the_projects_it_lists()
    {
        var report = Analyzer.Analyze(
            Path.Combine(Fixtures.PathTo(Fixtures.SolutionScope), "SolutionScope.sln"),
            configPath: null
        );

        Assert.Equal("solution", report.Scope.RootKind);
        Assert.Equal(2, report.Scope.ProjectsInScope);
        Assert.Equal("Sln.Domain", Assert.Single(report.Violations).FromProject);
    }

    [Fact]
    public void A_folder_checks_everything_under_it_including_what_the_solution_left_out()
    {
        var report = Fixtures.Check(Fixtures.SolutionScope);

        Assert.Equal("directory", report.Scope.RootKind);
        Assert.Equal(3, report.Scope.ProjectsInScope);
        Assert.Equal(
            ["Sln.Domain", "Sln.Presentation"],
            report.Violations.Select(violation => violation.FromProject).Order().ToArray()
        );
    }

    [Fact]
    public void A_single_project_checks_that_project_and_loads_the_rest_only_to_resolve_it()
    {
        var report = Analyzer.Analyze(
            Fixtures.ProjectFile(Fixtures.DirectReference, "Direct.Presentation"),
            configPath: null
        );

        Assert.Equal("project", report.Scope.RootKind);
        Assert.Equal(1, report.Scope.ProjectsInScope);
        Assert.Equal("Presentation", Assert.Single(report.Violations).FromRing);
        Assert.True(report.Scope.ProjectsLoaded > report.Scope.ProjectsInScope);
    }

    [Fact]
    public void A_path_that_is_none_of_the_three_is_refused_rather_than_guessed_at()
    {
        var error = Assert.Throws<ArgumentException>(
            () => Analyzer.Analyze(Fixtures.ProjectFile(Fixtures.DirectReference, "Direct.Domain") + ".missing", null)
        );

        Assert.Contains(".csproj", error.Message);
    }
}
