using Microsoft.Extensions.Diagnostics.HealthChecks;

namespace IFX.ApiHost.Runtime;

public sealed record HealthContributorSnapshot(
    string Name,
    string Status,
    string ReasonCode,
    DateTimeOffset LastChecked,
    DateTimeOffset? LastSucceeded,
    long DurationMilliseconds);

public sealed record RuntimeHealthSnapshot(
    string Status,
    string ReasonCode,
    DateTimeOffset LastChecked,
    IReadOnlyList<HealthContributorSnapshot> Contributors);

public sealed class HealthSnapshotStore
{
    private RuntimeHealthSnapshot _snapshot = new(
        "Unhealthy",
        "G04-READY-CHECK-PENDING",
        DateTimeOffset.UtcNow,
        Array.Empty<HealthContributorSnapshot>());

    public RuntimeHealthSnapshot Snapshot => Volatile.Read(ref _snapshot);

    public void Update(HealthReport report, DateTimeOffset checkedAt)
    {
        var previous = Snapshot.Contributors.ToDictionary(item => item.Name, StringComparer.Ordinal);
        var contributors = report.Entries
            .OrderBy(entry => entry.Key, StringComparer.Ordinal)
            .Select(entry =>
            {
                previous.TryGetValue(entry.Key, out var prior);
                var succeeded = entry.Value.Status == HealthStatus.Healthy ? checkedAt : prior?.LastSucceeded;
                return new HealthContributorSnapshot(
                    entry.Key,
                    entry.Value.Status.ToString(),
                    ReasonFor(entry.Key, entry.Value.Status),
                    checkedAt,
                    succeeded,
                    (long)entry.Value.Duration.TotalMilliseconds);
            })
            .ToArray();

        var status = report.Status.ToString();
        Volatile.Write(ref _snapshot, new RuntimeHealthSnapshot(
            status,
            report.Status == HealthStatus.Healthy ? "G04-READY" : "G04-READY-DEPENDENCY-UNAVAILABLE",
            checkedAt,
            contributors));
    }

    public void RecordFailure(string reasonCode, DateTimeOffset checkedAt) =>
        Volatile.Write(ref _snapshot, Snapshot with
        {
            Status = "Unhealthy",
            ReasonCode = reasonCode,
            LastChecked = checkedAt
        });

    private static string ReasonFor(string name, HealthStatus status)
    {
        var normalized = new string(name
            .ToUpperInvariant()
            .Select(character => char.IsLetterOrDigit(character) ? character : '-')
            .ToArray())
            .Trim('-');
        return $"G04-HEALTH-{normalized}-{status.ToString().ToUpperInvariant()}";
    }
}
