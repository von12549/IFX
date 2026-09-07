using System.Security.Cryptography;
using System.Text;
using System.Text.Json;

namespace LayerGuard;

public sealed record BaselineEntry(
    string Fingerprint,
    string Rule,
    string FromProject,
    string ToProject,
    string Owner,
    string Reason,
    DateOnly CreatedOn,
    DateOnly ExpiresOn,
    string RemovalCriteria
);

public sealed record BaselineFile(
    int Version,
    string ToolVersion,
    string Ruleset,
    string RulesetHash,
    IReadOnlyList<BaselineEntry> Entries
);

public static class Baseline
{
    private static readonly JsonSerializerOptions Options = new()
    {
        WriteIndented = true,
        PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
    };

    public static Report Apply(Report report, string path, DateOnly? today = null)
    {
        var fullPath = Paths.Normalize(path);
        var baseline = Read(fullPath, today ?? DateOnly.FromDateTime(DateTime.UtcNow));
        if (!string.Equals(baseline.ToolVersion, report.ToolVersion, StringComparison.Ordinal))
            throw new InvalidDataException(
                $"{fullPath} was created by {baseline.ToolVersion}, but this run uses {report.ToolVersion}. Regenerate it after review."
            );
        var activeRulesetHash = HashFile(report.Ruleset.Source);
        if (!string.Equals(baseline.RulesetHash, activeRulesetHash, StringComparison.OrdinalIgnoreCase))
            throw new InvalidDataException(
                $"{fullPath} does not match the active ruleset hash. Review the policy change and regenerate the baseline."
            );
        var fingerprints = baseline.Entries.Select(entry => entry.Fingerprint).ToHashSet(StringComparer.Ordinal);
        var actual = report.Violations.Select(Fingerprint).ToHashSet(StringComparer.Ordinal);
        var matched = actual.Count(fingerprints.Contains);
        var fresh = actual.Count - matched;
        var stale = fingerprints.Count(fingerprint => !actual.Contains(fingerprint));
        return report with
        {
            Verdict = fresh > 0 ? "new-violations" : stale > 0 ? "baseline-drift" : "baseline-clean",
            Baseline = new BaselineSummary(fullPath, matched, fresh, stale, baseline.Entries.Count),
        };
    }

    public static BaselineFile Snapshot(
        Report report,
        string owner,
        string reason,
        DateOnly expiresOn,
        string removalCriteria
    ) => new(
        1,
        report.ToolVersion,
        report.Ruleset.Source,
        HashFile(report.Ruleset.Source),
        report.Violations.Select(violation => new BaselineEntry(
                Fingerprint(violation),
                violation.Rule,
                violation.FromProject,
                violation.ToProject,
                owner,
                reason,
                DateOnly.FromDateTime(DateTime.UtcNow),
                expiresOn,
                removalCriteria
            ))
            .OrderBy(entry => entry.Fingerprint, StringComparer.Ordinal)
            .ToList()
    );

    public static void Write(BaselineFile baseline, string path) =>
        File.WriteAllText(Paths.Normalize(path), JsonSerializer.Serialize(baseline, Options) + Environment.NewLine);

    public static BaselineFile Read(string path, DateOnly today)
    {
        var baseline = JsonSerializer.Deserialize<BaselineFile>(
            File.ReadAllText(path),
            new JsonSerializerOptions { PropertyNameCaseInsensitive = true }
        ) ?? throw new InvalidDataException($"{path} is empty");

        if (baseline.Version != 1)
            throw new InvalidDataException($"{path} baseline version {baseline.Version} is unsupported; use 1.");
        if (string.IsNullOrWhiteSpace(baseline.RulesetHash))
            throw new InvalidDataException($"{path} requires rulesetHash.");
        var duplicate = baseline.Entries.GroupBy(entry => entry.Fingerprint).FirstOrDefault(group => group.Count() > 1);
        if (duplicate is not null)
            throw new InvalidDataException($"{path} contains duplicate fingerprint {duplicate.Key}.");
        foreach (var entry in baseline.Entries)
        {
            if (string.IsNullOrWhiteSpace(entry.Owner)
                || string.IsNullOrWhiteSpace(entry.Reason)
                || string.IsNullOrWhiteSpace(entry.RemovalCriteria))
                throw new InvalidDataException(
                    $"{path} entry {entry.Fingerprint} requires owner, reason, and removalCriteria."
                );
            if (entry.ExpiresOn < entry.CreatedOn)
                throw new InvalidDataException($"{path} entry {entry.Fingerprint} expires before it was created.");
            if (entry.ExpiresOn < today)
                throw new InvalidDataException(
                    $"{path} entry {entry.Fingerprint} expired on {entry.ExpiresOn:yyyy-MM-dd}."
                );
        }
        return baseline;
    }

    public static string Fingerprint(Violation violation)
    {
        var stable = string.Join(
            "|",
            violation.Rule,
            violation.FromProject,
            violation.ToProject,
            violation.Kind,
            StablePath(violation.Evidence.File),
            string.Join(" ", violation.Evidence.Text.Split((char[]?)null, StringSplitOptions.RemoveEmptyEntries))
        );
        return Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(stable))).ToLowerInvariant()[..20];
    }

    private static string StablePath(string path)
    {
        var normalized = path.Replace('\\', '/');
        foreach (var marker in new[] { "/src/", "/mcp/", "/tests/" })
        {
            var index = normalized.IndexOf(marker, StringComparison.OrdinalIgnoreCase);
            if (index >= 0)
                return normalized[(index + 1)..];
        }
        return Path.GetFileName(path);
    }

    private static string HashFile(string path) => File.Exists(path)
        ? Convert.ToHexString(SHA256.HashData(File.ReadAllBytes(path))).ToLowerInvariant()
        : Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(path))).ToLowerInvariant();
}
