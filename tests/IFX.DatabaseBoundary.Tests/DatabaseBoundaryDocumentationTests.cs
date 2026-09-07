using FluentAssertions;
using Xunit;

namespace IFX.DatabaseBoundary.Tests;

public sealed class DatabaseBoundaryDocumentationTests
{
    private static readonly string[] DiagramNames =
    [
        "database-architecture",
        "history-bootstrap",
        "production-migration-flow",
        "failure-recovery",
        "expand-contract"
    ];

    [Fact]
    public void Bilingual_documents_keep_decisions_and_operational_contract_aligned()
    {
        var gateDirectory = Path.Combine(
            RepositoryRoot(), "docs", "architecture", "review", "gates", "G02");
        var english = File.ReadAllText(Path.Combine(gateDirectory, "database-boundary.en.md"));
        var chinese = File.ReadAllText(Path.Combine(gateDirectory, "database-boundary.zh-CN.md"));

        foreach (var text in new[] { english, chinese })
        {
            text.Should().Contain("G02-D01–D07");
            text.Should().Contain("G02-D08–D15");
            text.Should().Contain("G02-D16–D20");
            text.Should().Contain("G02-D21–D25");
            text.Should().Contain("G02-D26");
            text.Should().Contain("AuthDatabase");
            text.Should().Contain("CrmDatabase");
            text.Should().Contain("RegistryDatabase");
            text.Should().Contain("HoldingsDatabase");
            text.Should().Contain("TransactionDatabase");
            text.Should().Contain("/health/database");
            text.Should().Contain("Plan 02 E2/E4");
            text.Should().Contain("ADR-G02-001");

            foreach (var diagram in DiagramNames)
            {
                text.Should().Contain($"diagrams/{diagram}.mmd");
                text.Should().Contain($"diagrams/{diagram}.svg");
            }
        }
    }

    [Fact]
    public void Every_mermaid_source_has_nonempty_svg_and_png_renderings()
    {
        var diagramDirectory = Path.Combine(
            RepositoryRoot(), "docs", "architecture", "review", "gates", "G02", "diagrams");

        foreach (var diagram in DiagramNames)
        {
            AssertArtifact(diagramDirectory, diagram, ".mmd", "");
            AssertArtifact(diagramDirectory, diagram, ".svg", "<svg");
            AssertArtifact(diagramDirectory, diagram, ".png", "PNG");
        }
    }

    private static void AssertArtifact(string directory, string name, string extension, string marker)
    {
        var path = Path.Combine(directory, name + extension);
        File.Exists(path).Should().BeTrue($"{name}{extension} is a Phase 9 deliverable");
        var bytes = File.ReadAllBytes(path);
        bytes.Length.Should().BeGreaterThan(100);

        if (extension == ".png")
        {
            bytes.Take(8).Should().Equal(137, 80, 78, 71, 13, 10, 26, 10);
        }
        else if (extension == ".svg")
        {
            File.ReadAllText(path).Should().Contain(marker);
        }
    }

    private static string RepositoryRoot()
    {
        var directory = new DirectoryInfo(AppContext.BaseDirectory);
        while (directory is not null && !File.Exists(Path.Combine(directory.FullName, "IFX.sln")))
        {
            directory = directory.Parent;
        }

        return directory?.FullName
            ?? throw new DirectoryNotFoundException("Could not locate repository root.");
    }
}
