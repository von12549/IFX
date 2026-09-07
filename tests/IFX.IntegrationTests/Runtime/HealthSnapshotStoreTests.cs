using IFX.ApiHost.Runtime;
using Microsoft.Extensions.Diagnostics.HealthChecks;

namespace IFX.IntegrationTests.Runtime;

public sealed class HealthSnapshotStoreTests
{
    [Fact]
    public void Update_EmitsStableSanitizedReasons_AndPreservesLastSuccess()
    {
        var store = new HealthSnapshotStore();
        var successAt = DateTimeOffset.Parse("2026-01-01T00:00:00Z");
        store.Update(Report(HealthStatus.Healthy), successAt);

        var failedAt = successAt.AddMinutes(1);
        store.Update(Report(HealthStatus.Unhealthy), failedAt);

        var contributor = store.Snapshot.Contributors.Should().ContainSingle().Subject;
        contributor.ReasonCode.Should().Be("G04-HEALTH-AUTH-SQL-UNHEALTHY");
        contributor.LastChecked.Should().Be(failedAt);
        contributor.LastSucceeded.Should().Be(successAt);
    }

    private static HealthReport Report(HealthStatus status)
    {
        var entry = new HealthReportEntry(
            status,
            description: "must not be copied",
            duration: TimeSpan.FromMilliseconds(12),
            exception: new Exception("must not be copied"),
            data: new Dictionary<string, object>(),
            tags: new[] { "api" });
        return new HealthReport(new Dictionary<string, HealthReportEntry> { ["Auth SQL"] = entry }, TimeSpan.FromMilliseconds(12));
    }
}
