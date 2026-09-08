namespace LayerGuard;

public enum Ring
{
    Domain,
    Contracts,
    Application,
    Presentation,
    IntegrationAdapter,
    Infrastructure,
    Composition,
    RuntimeHost,
    Test,
    Outside,
}

/// Where a fact was read, so a human can open the exact line.
public sealed record SourceSpan(string File, int Line, string Text);

public sealed record ProjectReferenceEntry(
    string ResolvedPath,
    string RawInclude,
    bool StopsTransitiveFlow,
    SourceSpan Source
);

public sealed record PackageReferenceEntry(
    string Id,
    string? Version,
    bool StopsTransitiveFlow,
    SourceSpan Source
);

public sealed record ProjectFile(
    string FullPath,
    string Name,
    string Sdk,
    string? Module,
    bool TransitiveReferencesDisabled,
    IReadOnlyList<ProjectReferenceEntry> ProjectReferences,
    IReadOnlyList<PackageReferenceEntry> PackageReferences,
    IReadOnlyList<string> FrameworkReferences
);

public sealed record GraphEdge(
    string FromPath,
    string FromName,
    string ToPath,
    string ToName,
    SourceSpan Source,
    bool StopsTransitiveFlow
);

/// One project as the analyzer sees it: the file plus the ring it was assigned to.
public sealed record ProjectNode(ProjectFile File, Ring Ring, string? Module)
{
    public string Name => File.Name;
    public string FullPath => File.FullPath;
    public bool InScope => Ring != Ring.Outside;
}

public sealed record BaselineSummary(
    string? Source,
    int Matched,
    int New,
    int Stale,
    int TotalEntries
);

public sealed record FindingCluster(
    string FromProject,
    string ToProject,
    IReadOnlyList<string> Rules,
    int Findings
);

public sealed record Violation(
    string Id,
    string Rule,
    string Severity,
    string Headline,
    string FromProject,
    string FromRing,
    string? FromModule,
    string ToProject,
    string ToRing,
    string? ToModule,
    string Kind,
    IReadOnlyList<string> Path,
    SourceSpan Evidence,
    SourceSpan FixAt,
    string FixHint,
    /// The numbered rule of the codebase's own rulebook this finding answers to, or null when
    /// the rulebook claims none. Set from the rule file, never worked out from the finding.
    string? Ref = null
);

/// One numbered rule of the rulebook, and what this run did about it. This is the audit's own
/// table, computed: a rule with no `SettledBy` was measured by nothing, and one carrying
/// `NotMeasured` was measured in part, whatever its finding count says.
public sealed record RuleRefResult(
    string Ref,
    string? Text,
    IReadOnlyList<string> SettledBy,
    string Coverage,
    string? NotMeasured,
    int Findings
);

public sealed record ProjectSummary(
    string Name,
    string Ring,
    string? Module,
    string File,
    int DirectProjectReferences,
    int Packages
);

public sealed record ScopeInfo(
    string Root,
    string RootKind,
    int ProjectsLoaded,
    int ProjectsInScope,
    int ProjectsOutside
);

public sealed record RulesetInfo(
    string Source,
    string Hash,
    IReadOnlyDictionary<string, string[]> AllowedDependencies,
    IReadOnlyList<PolicyBindingInfo> PolicyBindings,
    WaiverPolicyInfo? WaiverPolicy
);

public sealed record Report(
    string Tool,
    string ToolVersion,
    IReadOnlyList<string> Checked,
    ScopeInfo Scope,
    RulesetInfo Ruleset,
    IReadOnlyList<RuleRefResult> Rulebook,
    string Verdict,
    int ViolationCount,
    IReadOnlyList<Violation> Violations,
    IReadOnlyList<FindingCluster> Clusters,
    IReadOnlyList<ProjectSummary> Projects,
    IReadOnlyList<ProjectSummary> Outside,
    IReadOnlyList<string> NotChecked,
    long DurationMs,
    BaselineSummary? Baseline = null
);
