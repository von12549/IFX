using LayerGuard;
using Xunit;

namespace LayerGuard.Tests;

public class BaselineTests
{
    [Fact]
    public void Snapshot_suppresses_only_matching_historical_findings()
    {
        var report = Fixtures.Check(Fixtures.BootstrapArchitecture);
        var baseline = Baseline.Snapshot(
            report,
            "architecture-team",
            "bootstrap debt",
            DateOnly.FromDateTime(DateTime.UtcNow.AddDays(30)),
            "Remove after migration"
        );
        var path = Path.Combine(Path.GetTempPath(), $"layerguard-{Guid.NewGuid():N}.json");
        try
        {
            Baseline.Write(baseline, path);
            var applied = Baseline.Apply(report, path);
            Assert.Equal("baseline-clean", applied.Verdict);
            Assert.Equal(0, applied.Baseline!.New);
            Assert.Equal(report.ViolationCount, applied.Baseline.Matched);
        }
        finally
        {
            File.Delete(path);
        }
    }

    [Fact]
    public void Expired_waiver_fails_closed()
    {
        var report = Fixtures.Check(Fixtures.BootstrapArchitecture);
        var baseline = Baseline.Snapshot(
            report,
            "architecture-team",
            "bootstrap debt",
            new DateOnly(2099, 1, 1),
            "Remove after migration"
        );
        var path = Path.Combine(Path.GetTempPath(), $"layerguard-{Guid.NewGuid():N}.json");
        try
        {
            Baseline.Write(baseline, path);
            var error = Assert.Throws<InvalidDataException>(() =>
                Baseline.Apply(report, path, new DateOnly(2100, 1, 1))
            );
            Assert.Contains("expired", error.Message);
        }
        finally
        {
            File.Delete(path);
        }
    }

    [Fact]
    public void Fingerprint_is_stable_for_the_same_finding()
    {
        var finding = Fixtures.Check(Fixtures.BootstrapArchitecture).Violations[0];
        Assert.Equal(Baseline.Fingerprint(finding), Baseline.Fingerprint(finding));
    }

    [Fact]
    public void Ruleset_hash_is_stable_across_line_endings()
    {
        var sourcePath = Path.Combine(Path.GetTempPath(), $"layerguard-policy-{Guid.NewGuid():N}.json");
        var baselinePath = Path.Combine(Path.GetTempPath(), $"layerguard-{Guid.NewGuid():N}.json");
        try
        {
            File.WriteAllText(sourcePath, "{\n  \"requireRings\": false\n}\n");
            var original = Fixtures.Check(Fixtures.BootstrapArchitecture);
            var report = original with { Ruleset = original.Ruleset with { Source = sourcePath } };
            var baseline = Baseline.Snapshot(
                report,
                "architecture-team",
                "bootstrap debt",
                DateOnly.FromDateTime(DateTime.UtcNow.AddDays(30)),
                "Remove after migration"
            );
            Baseline.Write(baseline, baselinePath);

            File.WriteAllText(sourcePath, "{\r\n  \"requireRings\": false\r\n}\r\n");

            var applied = Baseline.Apply(report, baselinePath);
            Assert.Equal("baseline-clean", applied.Verdict);
        }
        finally
        {
            File.Delete(sourcePath);
            File.Delete(baselinePath);
        }
    }

    [Fact]
    public void Removed_findings_are_reported_as_stale_baseline_debt()
    {
        var report = Fixtures.Check(Fixtures.BootstrapArchitecture);
        var baseline = Baseline.Snapshot(
            report,
            "architecture-team",
            "bootstrap debt",
            DateOnly.FromDateTime(DateTime.UtcNow.AddDays(30)),
            "Remove after migration"
        );
        var path = Path.Combine(Path.GetTempPath(), $"layerguard-{Guid.NewGuid():N}.json");
        try
        {
            Baseline.Write(baseline, path);
            var reduced = report with { Violations = report.Violations.Skip(1).ToList(), ViolationCount = report.ViolationCount - 1 };
            var applied = Baseline.Apply(reduced, path);
            Assert.Equal("baseline-drift", applied.Verdict);
            Assert.Equal(1, applied.Baseline!.Stale);
        }
        finally
        {
            File.Delete(path);
        }
    }
}
