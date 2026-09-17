using System.Diagnostics;
using System.Text;
using System.Text.Json;
using System.Text.RegularExpressions;
using System.Xml.Linq;
using Xunit;

namespace GuardV3.Generated;

public sealed class GuardTests
{
    private static readonly StringComparison PathComparison = OperatingSystem.IsWindows() ? StringComparison.OrdinalIgnoreCase : StringComparison.Ordinal;

    private static string TargetRoot => Path.GetFullPath(Environment.GetEnvironmentVariable("GUARD_TARGET_ROOT")
        ?? throw new InvalidOperationException("GUARD_TARGET_ROOT is required."));

    private static IReadOnlyList<JsonElement> Rules()
    {
        var directory = Path.Combine(AppContext.BaseDirectory, "rules");
        var files = Directory.GetFiles(directory, "*.json").OrderBy(x => x, StringComparer.Ordinal).ToArray();
        Assert.NotEmpty(files);
        return files.Select(path => JsonDocument.Parse(File.ReadAllText(path)).RootElement.Clone()).ToArray();
    }

    private static string Property(JsonElement value, string name) => value.GetProperty(name).GetString()
        ?? throw new InvalidOperationException($"Missing {name}.");

    private static bool Glob(string path, string pattern)
    {
        path = path.Replace('\\', '/');
        pattern = pattern.Replace('\\', '/');
        var expression = new StringBuilder("^");
        for (var i = 0; i < pattern.Length; i++)
        {
            if (i + 2 < pattern.Length && pattern[i] == '*' && pattern[i + 1] == '*' && pattern[i + 2] == '/')
            {
                expression.Append("(?:.*/)?");
                i += 2;
            }
            else if (i + 1 < pattern.Length && pattern[i] == '*' && pattern[i + 1] == '*')
            {
                expression.Append(".*");
                i++;
            }
            else if (pattern[i] == '*') expression.Append("[^/]*");
            else if (pattern[i] == '?') expression.Append("[^/]");
            else expression.Append(Regex.Escape(pattern[i].ToString()));
        }
        expression.Append('$');
        return Regex.IsMatch(path, expression.ToString(), RegexOptions.CultureInvariant | RegexOptions.IgnoreCase);
    }

    private static string Relative(string root, string path) => Path.GetRelativePath(root, path).Replace('\\', '/');

    private static IReadOnlyList<string> Violations(string root, JsonElement rule)
    {
        if (Property(rule, "kind") != "forbidden-project-reference")
            throw new InvalidOperationException($"Unsupported detector: {Property(rule, "kind")}");
        var sourcePattern = Property(rule, "sourcePattern");
        var forbiddenPattern = Property(rule, "forbiddenTargetPattern");
        var failures = new List<string>();
        var matchedSources = 0;
        foreach (var project in Directory.EnumerateFiles(root, "*.csproj", SearchOption.AllDirectories))
        {
            var source = Relative(root, project);
            var generatedRoot = Environment.GetEnvironmentVariable("GUARD_GENERATED_ROOT");
            if (!string.IsNullOrWhiteSpace(generatedRoot) &&
                Path.GetFullPath(project).StartsWith(Path.GetFullPath(generatedRoot) + Path.DirectorySeparatorChar, PathComparison)) continue;
            if (!Glob(source, sourcePattern)) continue;
            matchedSources++;
            var document = XDocument.Load(project);
            foreach (var reference in document.Descendants().Where(x => x.Name.LocalName == "ProjectReference"))
            {
                var include = (string?)reference.Attribute("Include");
                if (string.IsNullOrWhiteSpace(include)) continue;
                var normalizedInclude = include.Replace('\\', Path.DirectorySeparatorChar).Replace('/', Path.DirectorySeparatorChar);
                var target = Relative(root, Path.GetFullPath(Path.Combine(Path.GetDirectoryName(project)!, normalizedInclude)));
                if (Glob(target, forbiddenPattern)) failures.Add($"{Property(rule, "id")}: {source} -> {target}");
            }
        }
        if (matchedSources == 0) failures.Add($"{Property(rule, "id")}: no source project matched {sourcePattern}");
        return failures;
    }

    [Fact, Trait("Stage", "Self")]
    public void DetectorAcceptsAllowedReference()
    {
        using var fixture = new ProjectFixture("src/App/App.csproj", "../Core/Core.csproj");
        Assert.Empty(Violations(fixture.Root, FixtureRule()));
    }

    [Fact, Trait("Stage", "Self")]
    public void DetectorRejectsForbiddenReference()
    {
        using var fixture = new ProjectFixture("src/App/App.csproj", "../Legacy/Legacy.csproj");
        Assert.Single(Violations(fixture.Root, FixtureRule()));
    }

    [Fact, Trait("Stage", "Self")]
    public void DetectorRejectsWindowsStyleReferenceOnEveryPlatform()
    {
        using var fixture = new ProjectFixture("src/App/App.csproj", "..\\Legacy\\Legacy.csproj");
        Assert.Single(Violations(fixture.Root, FixtureRule()));
    }

    private static JsonElement FixtureRule() => JsonDocument.Parse("""
        {"id":"FIXTURE","kind":"forbidden-project-reference","sourcePattern":"src/**/*.csproj","forbiddenTargetPattern":"**/Legacy/*.csproj"}
        """).RootElement.Clone();

    [Fact, Trait("Stage", "Self")]
    public void EveryBlockingRuleHasAWorkingPositiveAndNegativeFixture()
    {
        foreach (var rule in Rules().Where(rule => Property(rule, "enforcement") == "blocking" && Property(rule, "kind") == "forbidden-project-reference"))
        {
            var example = rule.GetProperty("negativeFixture");
            var source = Property(example, "sourceProject");
            var forbidden = Property(example, "referenceInclude");
            using var positive = new ProjectFixture(source, null);
            Assert.Empty(Violations(positive.Root, rule));
            using var negative = new ProjectFixture(source, forbidden);
            Assert.Contains(Violations(negative.Root, rule), message => message.Contains(" -> ", StringComparison.Ordinal));
        }
    }

    [Fact, Trait("Stage", "Post")]
    public void TargetRepositorySatisfiesBlockingRules()
    {
        var root = TargetRoot;
        Assert.True(Directory.Exists(root), $"Missing target repository: {root}");
        var blocking = Rules().Where(rule => Property(rule, "enforcement") == "blocking" && Property(rule, "kind") == "forbidden-project-reference").ToArray();
        if (blocking.Length == 0) return;
        var failures = blocking.SelectMany(rule => Violations(root, rule)).ToArray();
        Assert.True(failures.Length == 0, string.Join(Environment.NewLine, failures));
    }

    [Fact, Trait("Stage", "Diff")]
    public void DiffStaysWithinDeclaredPlan()
    {
        var root = TargetRoot;
        var planPath = Environment.GetEnvironmentVariable("GUARD_PLAN_PATH")
            ?? throw new InvalidOperationException("GUARD_PLAN_PATH is required for Diff.");
        var baseRef = Environment.GetEnvironmentVariable("GUARD_BASE_REF")
            ?? throw new InvalidOperationException("GUARD_BASE_REF is required for Diff.");
        var headRef = Environment.GetEnvironmentVariable("GUARD_HEAD_REF");
        using var plan = JsonDocument.Parse(File.ReadAllText(planPath));
        var declared = plan.RootElement.GetProperty("plannedPaths").EnumerateArray()
            .Select(x => x.GetString()!).ToArray();
        var committedHead = !string.IsNullOrWhiteSpace(headRef);
        var range = baseRef;
        string? verifiedBase = null, verifiedHead = null, mergeBase = null;
        if (committedHead)
        {
            verifiedBase = Git(root, "rev-parse", "--verify", baseRef + "^{commit}").Trim();
            verifiedHead = Git(root, "rev-parse", "--verify", headRef! + "^{commit}").Trim();
            mergeBase = Git(root, "merge-base", verifiedBase, verifiedHead).Trim();
            if (string.IsNullOrWhiteSpace(mergeBase)) throw new InvalidOperationException("Diff has no merge base; fetch complete history.");
            range = mergeBase + ".." + verifiedHead;
        }
        // Plan 06 §12.3: NUL-separated raw diff without rename detection, so a rename is a deletion plus an addition.
        var parts = Git(root, "diff", "--raw", "-z", "--no-renames", "--no-abbrev", range, "--")
            .Split('\0', StringSplitOptions.RemoveEmptyEntries);
        var changed = new List<string>();
        var protectedDeletions = new List<string>();
        var protectedGitlinks = new List<string>();
        var deleted = new HashSet<string>(StringComparer.Ordinal);
        // Protected paths come from the package Diff configuration (Plan 06 P3.2). A trusted runner may pass a protected
        // change report whose verifier checked every protected deletion against base authorizations (D23); only a passing
        // report bound to this base, merge base, head and configuration exempts its deletions, and only in a committed range.
        var protection = Protection.Load();
        var allowed = committedHead ? protection.AllowedDeletions(verifiedBase!, mergeBase!, verifiedHead!) : new HashSet<string>(StringComparer.Ordinal);
        var legacy = committedHead ? protection.LegacyConsumedAuthorizations() : new HashSet<string>(StringComparer.Ordinal);
        for (var i = 0; i < parts.Length; i += 2)
        {
            if (i + 1 >= parts.Length || !parts[i].StartsWith(':')) throw new InvalidOperationException("Malformed git raw diff output.");
            var meta = parts[i][1..].Split(' ');
            if (meta.Length < 5) throw new InvalidOperationException("Malformed git raw diff record: " + parts[i]);
            var path = parts[i + 1].Replace('\\', '/');
            changed.Add(path);
            var isProtected = protection.IsProtected(path);
            if (isProtected && (meta[0] == "160000" || meta[1] == "160000")) protectedGitlinks.Add(path);
            if (meta[1] != "000000") continue;
            deleted.Add(path);
            if (isProtected && !allowed.Contains(path) && !legacy.Contains(path)) protectedDeletions.Add(path);
        }
        if (!committedHead) changed.AddRange(Git(root, "ls-files", "--others", "--exclude-standard", "-z")
            .Split('\0', StringSplitOptions.RemoveEmptyEntries).Select(x => x.Replace('\\', '/')));
        Assert.True(changed.Count > 0, "Diff changed set is empty; base/head inputs may be wrong or history may be incomplete.");
        Assert.True(protectedGitlinks.Count == 0, "Gitlinks in protected paths: " + string.Join(", ", protectedGitlinks));
        Assert.True(protectedDeletions.Count == 0, "Protected guard deletions: " + string.Join(", ", protectedDeletions));
        var unused = allowed.Where(path => !deleted.Contains(path)).OrderBy(x => x, StringComparer.Ordinal).ToArray();
        Assert.True(unused.Length == 0, "Allowed deletions were not deleted by this change: " + string.Join(", ", unused));
        var unconsumed = legacy.Where(path => !deleted.Contains(path)).OrderBy(x => x, StringComparer.Ordinal).ToArray();
        Assert.True(unconsumed.Length == 0, "Verified authorizations were not deleted by this change: " + string.Join(", ", unconsumed));
        var planRelative = Relative(root, planPath);
        var companion = planRelative.EndsWith(".plan.json", StringComparison.Ordinal)
            ? planRelative[..^".plan.json".Length] + ".md" : "";
        var decisions = plan.RootElement.GetProperty("decisionPaths").EnumerateArray().Select(x => x.GetString()!).ToArray();
        var outside = changed.Distinct(StringComparer.OrdinalIgnoreCase)
            .Where(path => path != planRelative && path != companion && !decisions.Contains(path, StringComparer.OrdinalIgnoreCase)
                && !declared.Contains(path, StringComparer.OrdinalIgnoreCase))
            .OrderBy(x => x, StringComparer.Ordinal).ToArray();
        Assert.True(outside.Length == 0, "Paths outside Plan: " + string.Join(", ", outside));
    }

    private sealed class Protection
    {
        private readonly string[] _paths;
        private readonly string? _authorizationDirectory;
        private readonly string? _sha256;

        private Protection(string[] paths, string? authorizationDirectory, string? sha256)
        {
            _paths = paths;
            _authorizationDirectory = authorizationDirectory;
            _sha256 = sha256;
        }

        // GUARD_PROTECTION_PATH names the package Diff configuration, validated by Invoke-V3 against protection.schema.json.
        // Without it no path is protected and no protected change report is accepted.
        public static Protection Load()
        {
            var file = Environment.GetEnvironmentVariable("GUARD_PROTECTION_PATH");
            if (string.IsNullOrWhiteSpace(file)) return new Protection(Array.Empty<string>(), null, null);
            var bytes = File.ReadAllBytes(file);
            using var document = JsonDocument.Parse(bytes);
            var paths = document.RootElement.GetProperty("protectedPaths").EnumerateArray().Select(x => x.GetString()!).ToArray();
            var directory = document.RootElement.TryGetProperty("authorizationDirectory", out var value) ? value.GetString() : null;
            return new Protection(paths, directory, Convert.ToHexString(System.Security.Cryptography.SHA256.HashData(bytes)).ToLowerInvariant());
        }

        // Entries ending in '/' protect a directory prefix, other entries one exact path; matching ignores case so a
        // case-only rename cannot escape protection.
        public bool IsProtected(string path) => _paths.Any(entry => entry.EndsWith('/')
            ? path.StartsWith(entry, StringComparison.OrdinalIgnoreCase)
            : path.Equals(entry, StringComparison.OrdinalIgnoreCase));

        // GUARD_PROTECTED_CHANGES names a protected change report (protected-change-report.schema.json). It must pass and
        // be bound to exactly this Diff; anything else fails instead of being ignored.
        public HashSet<string> AllowedDeletions(string baseSha, string mergeBase, string headSha)
        {
            var file = Environment.GetEnvironmentVariable("GUARD_PROTECTED_CHANGES");
            if (string.IsNullOrWhiteSpace(file)) return new HashSet<string>(StringComparer.Ordinal);
            if (_sha256 is null) throw new InvalidOperationException("GUARD_PROTECTED_CHANGES requires a Diff protection configuration.");
            using var report = JsonDocument.Parse(File.ReadAllBytes(file));
            var root = report.RootElement;
            string Text(string name) => root.TryGetProperty(name, out var value) && value.ValueKind == JsonValueKind.String ? value.GetString()! : "";
            foreach (var (name, expected) in new[] { ("check", "protected-changes"), ("status", "pass"), ("baseSha", baseSha), ("mergeBase", mergeBase), ("headSha", headSha), ("protectionSha256", _sha256) })
            {
                if (!string.Equals(Text(name), expected, StringComparison.Ordinal))
                    throw new InvalidOperationException($"GUARD_PROTECTED_CHANGES is not bound to this Diff: {name} is '{Text(name)}', expected '{expected}'.");
            }
            return new HashSet<string>(root.GetProperty("allowedDeletions").EnumerateArray().Select(x => x.GetString()!), StringComparer.Ordinal);
        }

        // Legacy D20 variable, kept only so that the base-owned tests of the previous trusted base still validate this
        // candidate (D23 expand/contract); trusted runners no longer set it and strip it from child processes. It names
        // authorization records whose plain deletion is exempt. Removed with CP06b.
        public HashSet<string> LegacyConsumedAuthorizations()
        {
            var value = Environment.GetEnvironmentVariable("GUARD_CONSUMED_AUTHORIZATIONS") ?? "";
            var paths = value.Split('\n', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries);
            foreach (var path in paths)
            {
                var name = _authorizationDirectory is not null && path.StartsWith(_authorizationDirectory, StringComparison.Ordinal) ? path[_authorizationDirectory.Length..] : "";
                if (name.Length == 0 || name.Contains('/') || !name.EndsWith(".json", StringComparison.Ordinal))
                    throw new InvalidOperationException("GUARD_CONSUMED_AUTHORIZATIONS may only name authorization records: " + path);
            }
            return new HashSet<string>(paths, StringComparer.Ordinal);
        }
    }

    private static string Git(string root, params string[] arguments)
    {
        using var process = new Process();
        process.StartInfo.FileName = "git";
        process.StartInfo.WorkingDirectory = root;
        process.StartInfo.RedirectStandardOutput = true;
        process.StartInfo.RedirectStandardError = true;
        foreach (var argument in arguments) process.StartInfo.ArgumentList.Add(argument);
        process.Start();
        var output = process.StandardOutput.ReadToEnd();
        var error = process.StandardError.ReadToEnd();
        process.WaitForExit();
        if (process.ExitCode != 0) throw new InvalidOperationException($"git {string.Join(' ', arguments)} failed: {error}");
        return output;
    }

    private sealed class ProjectFixture : IDisposable
    {
        public string Root { get; } = Path.Combine(Path.GetTempPath(), "guard-v3-" + Guid.NewGuid().ToString("N"));
        public ProjectFixture(string project, string? reference)
        {
            var path = Path.Combine(Root, project);
            Directory.CreateDirectory(Path.GetDirectoryName(path)!);
            File.WriteAllText(path, reference is null ? "<Project />" : $"<Project><ItemGroup><ProjectReference Include=\"{reference}\" /></ItemGroup></Project>");
        }
        public void Dispose() => Directory.Delete(Root, recursive: true);
    }
}
