namespace LayerGuard;

/// What `scan` hands back. No verdict, no severity, no rule id — a caller asking these questions
/// is doing its own judging, and a fact that arrives pre-judged cannot be reused for a question
/// the rule file never anticipated.
public sealed record ImportFact(
    string Project,
    string Ring,
    string? Module,
    string File,
    int Line,
    string Target,
    string? TargetProject,
    string? TargetRing,
    bool InInactiveBranch
);

public sealed record DeclarationFact(
    string Project,
    string Ring,
    string? Module,
    string File,
    int Line,
    string Kind,
    string Name,
    IReadOnlyList<string> BaseTypes
);

public sealed record PackageFact(
    string Project,
    string Ring,
    string? Module,
    string Id,
    string? Version,
    string File,
    int Line
);

public sealed record ScanResult(
    string Tool,
    string Select,
    ScopeInfo Scope,
    RulesetInfo Ruleset,
    int Count,
    IReadOnlyList<ProjectSummary>? Projects = null,
    IReadOnlyList<PackageFact>? Packages = null,
    IReadOnlyList<ImportFact>? Imports = null,
    IReadOnlyList<DeclarationFact>? Declarations = null
);
