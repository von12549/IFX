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
        if (committedHead)
        {
            var verifiedBase = Git(root, "rev-parse", "--verify", baseRef + "^{commit}").Trim();
            var verifiedHead = Git(root, "rev-parse", "--verify", headRef! + "^{commit}").Trim();
            var mergeBase = Git(root, "merge-base", verifiedBase, verifiedHead).Trim();
            if (string.IsNullOrWhiteSpace(mergeBase)) throw new InvalidOperationException("Diff has no merge base; fetch complete history.");
            range = mergeBase + ".." + verifiedHead;
        }
        var parts = Git(root, "diff", "--name-status", "-z", "--find-renames", range, "--")
            .Split('\0', StringSplitOptions.RemoveEmptyEntries);
        var changed = new List<string>();
        var protectedDeletions = new List<string>();
        for (var i = 0; i < parts.Length;)
        {
            var status = parts[i++];
            if (i >= parts.Length) throw new InvalidOperationException("Malformed git name-status output.");
            var firstPath = parts[i++].Replace('\\', '/');
            changed.Add(firstPath);
            if ((status.StartsWith('D') || status.StartsWith('R')) && IsProtectedGuardPath(firstPath)) protectedDeletions.Add(firstPath);
            if (status.StartsWith('R') || status.StartsWith('C'))
            {
                if (i >= parts.Length) throw new InvalidOperationException("Malformed git rename output.");
                changed.Add(parts[i++].Replace('\\', '/'));
            }
        }
        if (!committedHead) changed.AddRange(Git(root, "ls-files", "--others", "--exclude-standard", "-z")
            .Split('\0', StringSplitOptions.RemoveEmptyEntries).Select(x => x.Replace('\\', '/')));
        Assert.True(changed.Count > 0, "Diff changed set is empty; base/head inputs may be wrong or history may be incomplete.");
        Assert.True(protectedDeletions.Count == 0, "Protected guard deletions: " + string.Join(", ", protectedDeletions));
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

    private static bool IsProtectedGuardPath(string path) =>
        path.Equals(".github/CODEOWNERS", StringComparison.OrdinalIgnoreCase) ||
        path.Equals(".github/workflows/v3-ifx-guardrails.yml", StringComparison.OrdinalIgnoreCase) ||
        path.StartsWith("mcp/LayerGuard/", StringComparison.OrdinalIgnoreCase) ||
        path.StartsWith("docs/guards/plans/", StringComparison.OrdinalIgnoreCase) ||
        path.StartsWith("docs/guards/V3/", StringComparison.OrdinalIgnoreCase) ||
        path.StartsWith("docs/guards/V3_backup/", StringComparison.OrdinalIgnoreCase) ||
        path.StartsWith("docs/guards/V3_ifx/", StringComparison.OrdinalIgnoreCase);

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
