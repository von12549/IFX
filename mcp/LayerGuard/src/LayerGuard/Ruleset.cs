using System.Text.Json;
using System.Text.Json.Serialization;
using System.Text.RegularExpressions;

namespace LayerGuard;

/// Every rule this tool enforces is data in here, not code. A codebase states its own layer
/// names, its own directions, which packages a layer may hold, which projects a layer may never
/// name, and where a kind of type has to be declared. Nothing below is specific to any codebase,
/// and a rule nobody wrote down is a rule nobody is judged by.
public sealed class Ruleset
{
    public const string FileName = "layerguard.json";

    public required string Source { get; init; }
    public required string PolicyHash { get; init; }
    public IReadOnlyList<PolicyBindingInfo> PolicyBindings { get; init; } = [];
    public WaiverPolicyInfo? WaiverPolicy { get; init; }
    public IReadOnlyList<string> SharedPrimitiveProjects { get; init; } = [];
    public required IReadOnlyDictionary<Ring, string[]> RingPatterns { get; init; }
    public required IReadOnlyDictionary<Ring, Ring[]> AllowedDependencies { get; init; }
    public IReadOnlyList<ReferenceScopeRule> ReferenceScopes { get; init; } = [];
    public string[] ModulePatterns { get; init; } = [];
    public bool RequireKnownOwnership { get; init; }
    public IReadOnlyDictionary<string, string[]> ProviderContracts { get; init; } =
        new Dictionary<string, string[]>(StringComparer.OrdinalIgnoreCase);
    public string[] ForbiddenProjectNames { get; init; } = [];
    public IReadOnlyDictionary<Ring, string[]> ForbiddenNamespaces { get; init; } =
        new Dictionary<Ring, string[]>();
    public IReadOnlyDictionary<Ring, string[]> ForbiddenSymbols { get; init; } =
        new Dictionary<Ring, string[]>();
    public IReadOnlyDictionary<Ring, string[]> ForbiddenText { get; init; } =
        new Dictionary<Ring, string[]>();
    public IReadOnlyList<NamespaceDeclarationRule> DeclarationNamespaces { get; init; } = [];
    public IReadOnlyList<ForbiddenDeclarationRule> ForbiddenDeclarations { get; init; } = [];
    public IReadOnlyList<PayloadRule> Payloads { get; init; } = [];
    public string[] EmbeddedAdapterNamespaces { get; init; } = [];
    public Ring[] TransitiveBoundaryRoles { get; init; } = [];

    /// A ring listed here may hold only packages matching one of its patterns. An empty list
    /// means no package at all. A ring that is absent is not checked — silence is not consent.
    public IReadOnlyDictionary<Ring, string[]> AllowedPackages { get; init; } =
        new Dictionary<Ring, string[]>();

    /// Packages a ring may never hold, whatever else it is allowed. An allow-list cannot say
    /// this: a ring that legitimately holds many packages would have to enumerate all of them to
    /// refuse one. A ring that is absent is not checked.
    public IReadOnlyDictionary<Ring, string[]> ForbiddenPackages { get; init; } =
        new Dictionary<Ring, string[]>();

    /// Project names no project may reference, whatever the direction table says about their
    /// rings. This is how a rule about a project that matches no ring gets expressed at all.
    /// The only projects a ring may name in its own project file. This is the allow-list half:
    /// the direction table rules on pairs of rings, and says nothing at all about a project that
    /// matches no ring, so "this layer may reference these and nothing else" cannot be stated by
    /// refusing directions. A ring that is absent is not checked.
    public IReadOnlyDictionary<Ring, string[]> AllowedReferences { get; init; } =
        new Dictionary<Ring, string[]>();

    public string[] ForbiddenInSameModule { get; init; } = [];
    public IReadOnlyDictionary<Ring, string[]> ForbiddenByRing { get; init; } =
        new Dictionary<Ring, string[]>();

    /// Types a ring may never take as a constructor parameter. A reference says a layer can see
    /// something and an import says a file names it; this says a type was handed one to hold.
    /// A ring that is absent is not checked.
    public IReadOnlyDictionary<Ring, string[]> ForbiddenDependencies { get; init; } =
        new Dictionary<Ring, string[]>();

    /// The pattern that forbids this ring from being handed that type, or null if none does.
    public string? ForbidsDependency(Ring ring, string typeName) =>
        ForbiddenDependencies.TryGetValue(ring, out var patterns)
            ? patterns.FirstOrDefault(pattern => Matches(typeName, pattern))
            : null;

    /// Rings whose types a ring may not be handed. The sibling above matches a name; this asks
    /// where the type was declared, which is what "never a concrete class from Infrastructure"
    /// actually says — a naming convention would have to be invented to express it otherwise.
    public IReadOnlyDictionary<Ring, Ring[]> ForbiddenDependencyOrigins { get; init; } =
        new Dictionary<Ring, Ring[]>();

    /// Where a kind of type has to be declared, matched on the type's own name.
    public IReadOnlyList<DeclarationRule> Declarations { get; init; } = [];

    /// The rulebook this codebase is audited against, keyed to the rule ids this tool emits. A
    /// tool rule id says which check failed; a rulebook says which numbered rule a reader was
    /// promised an answer to, and the two are many-to-many — one id serves four rules that differ
    /// only by ring, and one rule is settled by three ids at once. Stating the mapping here is
    /// what stops it being re-derived, differently, by whoever reads the report.
    public IReadOnlyList<RuleRef> RuleRefs { get; init; } = [];

    /// The rulebook entry a finding answers to, or null when the rulebook claims none. First
    /// match wins, so a narrower entry is written above the entry it carves out of.
    public RuleRef? RefFor(string rule, Ring fromRing, bool sameModule) =>
        RuleRefs.FirstOrDefault(entry =>
            entry.Rules.Contains(rule, StringComparer.Ordinal)
            && (entry.Ring is null || entry.Ring == fromRing)
            && (entry.SameModule is null || entry.SameModule == sameModule)
        );

    /// How loudly a rule speaks, keyed by its id. A rulebook that calls one rule a break and
    /// another a bend is making a claim about what a reader should do first, and a tool that
    /// reports every finding at one level has thrown that claim away.
    public IReadOnlyDictionary<string, string> Severities { get; init; } =
        new Dictionary<string, string>();

    /// The severity stated for this rule, or the one the rule itself carries.
    public string SeverityOf(string ruleId, string fallback = Breaks) =>
        Severities.TryGetValue(ruleId, out var stated) ? stated : fallback;

    public const string Breaks = "breaks";
    public const string Bends = "bends";
    public const string Drift = "drift";

    /// Every module must hold a project in each ring the layer patterns name.
    public bool RequireRings { get; init; }

    /// The four rings and the direction Clean Architecture allows. Domain depends on nothing.
    /// Presentation and Infrastructure are siblings and never see each other.
    public static Ruleset Default { get; } =
        new()
        {
            Source = "built-in default",
            PolicyHash = GatePolicyLoader.CompositeHash([]),
            RingPatterns = new Dictionary<Ring, string[]>
            {
                [Ring.Domain] = ["*.Domain"],
                [Ring.Application] = ["*.Application"],
                [Ring.Presentation] = ["*.Presentation"],
                [Ring.Infrastructure] = ["*.Infrastructure"],
            },
            AllowedDependencies = new Dictionary<Ring, Ring[]>
            {
                [Ring.Domain] = [],
                [Ring.Application] = [Ring.Domain],
                [Ring.Presentation] = [Ring.Application, Ring.Domain],
                [Ring.Infrastructure] = [Ring.Application, Ring.Domain],
            },
        };

    public Ring RingOf(string projectName)
    {
        foreach (var (ring, patterns) in RingPatterns)
        {
            if (patterns.Any(pattern => Matches(projectName, pattern)))
                return ring;
        }
        return Ring.Outside;
    }

    public bool Allows(Ring from, Ring to) =>
        from == to || (AllowedDependencies.TryGetValue(from, out var allowed) && allowed.Contains(to));

    public bool AllowsOwnership(Ring from, Ring to, string? fromModule, string? toModule)
    {
        var constraints = ReferenceScopes.Where(rule => rule.From == from && rule.To == to).ToList();
        if (constraints.Count == 0)
            return true;

        var relationship = fromModule is not null
            && string.Equals(fromModule, toModule, StringComparison.OrdinalIgnoreCase)
                ? "own"
                : "foreign";
        return constraints.Any(rule =>
            rule.Ownership.Equals("any", StringComparison.OrdinalIgnoreCase)
            || rule.Ownership.Equals(relationship, StringComparison.OrdinalIgnoreCase)
        );
    }

    public bool IsApprovedProvider(string consumer, string provider) =>
        ProviderContracts.TryGetValue(consumer, out var providers)
        && providers.Contains(provider, StringComparer.OrdinalIgnoreCase);

    public bool IsSharedPrimitiveReference(ProjectNode source, string targetName) =>
        source.Ring == Ring.Contracts
        && !SharedPrimitiveProjects.Contains(source.Name, StringComparer.OrdinalIgnoreCase)
        && SharedPrimitiveProjects.Contains(targetName, StringComparer.OrdinalIgnoreCase);

    public string? ModuleOf(ProjectFile file, Ring role)
    {
        foreach (var pattern in ModulePatterns)
        {
            var expression = "^"
                + Regex.Escape(pattern)
                    .Replace("\\{module}", "(?<module>[^.]+)")
                    .Replace("\\*", ".*")
                + "$";
            var match = Regex.Match(file.Name, expression, RegexOptions.IgnoreCase);
            if (match.Success)
                return match.Groups["module"].Value;
        }

        return role is Ring.RuntimeHost or Ring.Test ? null : file.Module;
    }

    /// null when the ring states no package rule at all, which is not the same as stating an
    /// empty one: the first is unchecked, the second forbids everything.
    public string[]? PackagesAllowedIn(Ring ring) =>
        AllowedPackages.TryGetValue(ring, out var allowed) ? allowed : null;

    /// The pattern that forbids this package outright, or null if none does. Checked before the
    /// allow-list, so a package named by both is reported once, under the rule that names it.
    public string? ForbidsPackage(Ring ring, string id) =>
        ForbiddenPackages.TryGetValue(ring, out var patterns)
            ? patterns.FirstOrDefault(pattern => Matches(id, pattern))
            : null;

    /// null when the ring states no reference rule at all, which is not the same as stating an
    /// empty one: the first is unchecked, the second allows the ring to name nothing.
    public string[]? ReferencesAllowedIn(Ring ring) =>
        AllowedReferences.TryGetValue(ring, out var allowed) ? allowed : null;

    /// The pattern that forbids this reference, or null if none does.
    public string? ForbidsReference(Ring from, string targetName, bool sameModule)
    {
        if (sameModule)
        {
            var inModule = ForbiddenInSameModule.FirstOrDefault(pattern => Matches(targetName, pattern));
            if (inModule is not null)
                return inModule;
        }

        return ForbiddenByRing.TryGetValue(from, out var patterns)
            ? patterns.FirstOrDefault(pattern => Matches(targetName, pattern))
            : null;
    }

    public static bool Matches(string value, string pattern)
    {
        var expression = "^" + Regex.Escape(pattern).Replace("\\*", ".*") + "$";
        return Regex.IsMatch(value, expression, RegexOptions.IgnoreCase);
    }

    /// Walks up from the given path looking for a config file, the way MSBuild finds its own.
    public static Ruleset Load(string startPath, string? explicitConfigPath)
    {
        if (!string.IsNullOrWhiteSpace(explicitConfigPath))
            return FromFile(Paths.Normalize(explicitConfigPath));

        var directory = Directory.Exists(startPath)
            ? new DirectoryInfo(startPath)
            : new FileInfo(startPath).Directory;

        while (directory is not null)
        {
            var candidate = Path.Combine(directory.FullName, FileName);
            if (File.Exists(candidate))
                return FromFile(candidate);
            directory = directory.Parent;
        }

        return Default;
    }

    private static Ruleset FromFile(string path)
    {
        var document = JsonSerializer.Deserialize<RulesetDocument>(
            File.ReadAllText(path),
            new JsonSerializerOptions
            {
                PropertyNameCaseInsensitive = true,
                ReadCommentHandling = JsonCommentHandling.Skip,
                AllowTrailingCommas = true,
                UnmappedMemberHandling = JsonUnmappedMemberHandling.Disallow,
                Converters = { new JsonStringEnumConverter() },
            }
        );

        if (document is null)
            throw new InvalidDataException($"{path} is empty");

        Validate(document, path);
        var gatePolicies = GatePolicyLoader.Load(document.GatePolicies, path);
        ValidateGateRoleBinding(document, path);
        if (document.GatePolicies is not null && (document.ProviderContracts?.Count ?? 0) > 0)
            throw new InvalidDataException(
                $"{path} must not copy providerContracts when gatePolicies is configured; consume the G03 governance input directly."
            );
        var providerContracts = document.GatePolicies is null
            ? document.ProviderContracts ?? new Dictionary<string, string[]>(StringComparer.OrdinalIgnoreCase)
            : gatePolicies.ProviderContracts;

        return new Ruleset
        {
            Source = path,
            PolicyHash = gatePolicies.CompositeHash,
            PolicyBindings = gatePolicies.Bindings,
            WaiverPolicy = gatePolicies.WaiverPolicy,
            SharedPrimitiveProjects = gatePolicies.SharedPrimitiveProjects,
            RingPatterns = ToRingMap(document.Rings) ?? Default.RingPatterns,
            AllowedDependencies = ToDependencyMap(document.AllowedDependencies) ?? Default.AllowedDependencies,
            ReferenceScopes = document.ReferenceScopes ?? [],
            ModulePatterns = document.Ownership?.ModulePatterns ?? [],
            RequireKnownOwnership = document.Ownership?.RequireKnown ?? false,
            ProviderContracts = providerContracts,
            ForbiddenProjectNames = document.ForbiddenProjectNames ?? [],
            ForbiddenNamespaces = ToRingMap(document.ForbiddenNamespaces) ?? new Dictionary<Ring, string[]>(),
            ForbiddenSymbols = ToRingMap(document.ForbiddenSymbols) ?? new Dictionary<Ring, string[]>(),
            ForbiddenText = ToRingMap(document.ForbiddenText) ?? new Dictionary<Ring, string[]>(),
            DeclarationNamespaces = document.DeclarationNamespaces ?? [],
            ForbiddenDeclarations = document.ForbiddenDeclarations ?? [],
            Payloads = document.Payloads ?? [],
            EmbeddedAdapterNamespaces = document.EmbeddedAdapterNamespaces ?? [],
            TransitiveBoundaryRoles = document.TransitiveBoundaryRoles ?? [],
            AllowedPackages = ToRingMap(document.AllowedPackages) ?? new Dictionary<Ring, string[]>(),
            ForbiddenPackages = ToRingMap(document.ForbiddenPackages) ?? new Dictionary<Ring, string[]>(),
            ForbiddenDependencies =
                ToRingMap(document.ForbiddenDependencies) ?? new Dictionary<Ring, string[]>(),
            AllowedReferences = ToRingMap(document.AllowedReferences) ?? new Dictionary<Ring, string[]>(),
            ForbiddenInSameModule = document.ForbiddenReferences?.SameModule ?? [],
            ForbiddenByRing =
                ToRingMap(document.ForbiddenReferences?.ByRing) ?? new Dictionary<Ring, string[]>(),
            Declarations = document.Declarations ?? [],
            ForbiddenDependencyOrigins =
                ToDependencyMap(document.ForbiddenDependencyOrigins) ?? new Dictionary<Ring, Ring[]>(),
            RuleRefs = ReadRuleRefs(document.RuleRefs, path),
            Severities = ReadSeverities(document.Severities, path),
            RequireRings = document.RequireRings ?? false,
        };
    }

    /// A rulebook naming a check this tool does not emit would match nothing, for ever, and
    /// silently — its rule would read as measured by something that never runs.
    private static IReadOnlyList<RuleRef> ReadRuleRefs(RuleRef[]? raw, string path)
    {
        if (raw is null)
            return [];

        foreach (var entry in raw)
        {
            foreach (var rule in entry.Rules)
            {
                if (!KnownRules.Contains(rule))
                    throw new InvalidDataException(
                        $"{path} says {entry.Ref} is settled by \"{rule}\", which is not a rule this "
                            + $"tool emits. It emits: {string.Join(", ", KnownRules.Order())}."
                    );
            }
        }

        return raw;
    }

    /// Every rule id a finding can arrive under. Named here so a rulebook pointing at a check
    /// that does not exist is refused when the file is read, not discovered by its absence.
    public static readonly IReadOnlySet<string> KnownRules = new HashSet<string>(StringComparer.Ordinal)
    {
        ReferenceRules.DirectionRule,
        ReferenceRules.ForbiddenRule,
        ReferenceRules.AllowedRule,
        ImportRules.DirectionRule,
        ImportRules.PackageRule,
        PackageRules.Rule,
        PackageRules.ForbiddenRule,
        DeclarationRules.Rule,
        DeclarationRules.ImplementsRule,
        InjectionRules.Rule,
        InjectionRules.OriginRule,
        StructureRules.Rule,
        OwnershipRules.UnknownOwnershipRule,
        OwnershipRules.ProjectNameRule,
        OwnershipRules.ScopeRule,
        OwnershipRules.ProviderRule,
        OwnershipRules.ProviderCycleRule,
        OwnershipRules.ContractCycleRule,
        SourcePolicyRules.NamespaceRuleId,
        SourcePolicyRules.ForbiddenDeclarationRuleId,
        SourcePolicyRules.ForbiddenSymbolRuleId,
        SourcePolicyRules.PayloadRuleId,
        EmbeddedAdapterRules.LocationRule,
        EmbeddedAdapterRules.ProviderRule,
    };

    /// A severity nobody recognises is refused at the door. Left through, it would produce
    /// findings that every reader filtering on the three known levels quietly drops.
    private static IReadOnlyDictionary<string, string> ReadSeverities(
        Dictionary<string, string>? raw,
        string path
    )
    {
        if (raw is null)
            return new Dictionary<string, string>();

        foreach (var (ruleId, severity) in raw)
        {
            if (!KnownRules.Contains(ruleId))
                throw new InvalidDataException($"{path} assigns severity to unknown rule `{ruleId}`.");
            if (severity is not (Breaks or Bends or Drift))
                throw new InvalidDataException(
                    $"{path} gives {ruleId} the severity \"{severity}\". "
                        + $"Use {Breaks}, {Bends} or {Drift}."
                );
        }

        return raw;
    }

    private static void Validate(RulesetDocument document, string path)
    {
        foreach (var pattern in document.Ownership?.ModulePatterns ?? [])
            if (pattern.Split("{module}", StringSplitOptions.None).Length != 2)
                throw new InvalidDataException(
                    $"{path} ownership pattern `{pattern}` must contain exactly one {{module}} token."
                );

        foreach (var scope in document.ReferenceScopes ?? [])
            if (scope.Ownership is not ("own" or "foreign" or "any" or "none"))
                throw new InvalidDataException(
                    $"{path} referenceScopes ownership `{scope.Ownership}` must be own, foreign, any, or none."
                );

        var duplicate = (document.ReferenceScopes ?? [])
            .GroupBy(scope => $"{scope.From}|{scope.To}|{scope.Ownership}", StringComparer.OrdinalIgnoreCase)
            .FirstOrDefault(group => group.Count() > 1);
        if (duplicate is not null)
            throw new InvalidDataException($"{path} contains duplicate reference scope `{duplicate.Key}`.");

        var duplicateNamespace = (document.DeclarationNamespaces ?? [])
            .GroupBy(rule => $"{rule.Match}|{rule.Kind}|{rule.Namespace}", StringComparer.OrdinalIgnoreCase)
            .FirstOrDefault(group => group.Count() > 1);
        if (duplicateNamespace is not null)
            throw new InvalidDataException($"{path} contains duplicate declaration namespace rule `{duplicateNamespace.Key}`.");
    }

    private static void ValidateGateRoleBinding(RulesetDocument document, string path)
    {
        if (document.GatePolicies is null)
            return;
        foreach (var role in new[] { Ring.Composition.ToString(), Ring.RuntimeHost.ToString() })
            if (document.Rings?.ContainsKey(role) != true)
                throw new InvalidDataException($"{path} must bind the G04 `{role}` project role.");
        if (document.AllowedDependencies is null
            || !document.AllowedDependencies.TryGetValue(Ring.RuntimeHost.ToString(), out var allowed)
            || allowed is null
            || allowed.Length != 1
            || !allowed[0].Equals(Ring.Composition.ToString(), StringComparison.OrdinalIgnoreCase))
            throw new InvalidDataException(
                $"{path} must bind G04 RuntimeHost references to Composition only."
            );
    }

    private static IReadOnlyDictionary<Ring, string[]>? ToRingMap(Dictionary<string, string[]>? raw) =>
        raw is null ? null : raw.ToDictionary(pair => ParseRing(pair.Key), pair => pair.Value);

    private static IReadOnlyDictionary<Ring, Ring[]>? ToDependencyMap(Dictionary<string, string[]>? raw) =>
        raw is null
            ? null
            : raw.ToDictionary(pair => ParseRing(pair.Key), pair => pair.Value.Select(ParseRing).ToArray());

    private static Ring ParseRing(string name) =>
        Enum.TryParse<Ring>(name, ignoreCase: true, out var ring)
            ? ring
            : throw new InvalidDataException(
                $"\"{name}\" is not a project role. Use one of: {string.Join(", ", Enum.GetNames<Ring>())}."
            );

    private sealed record OwnershipDocument(string[]? ModulePatterns, bool? RequireKnown);

    private sealed record ForbiddenReferencesDocument(
        string[]? SameModule,
        Dictionary<string, string[]>? ByRing
    );

    private sealed record RulesetDocument(
        [property: JsonPropertyName("_")] string[]? Comments,
        Dictionary<string, string>? Severities,
        RuleRef[]? RuleRefs,
        Dictionary<string, string[]>? Rings,
        Dictionary<string, string[]>? AllowedDependencies,
        ReferenceScopeRule[]? ReferenceScopes,
        OwnershipDocument? Ownership,
        Dictionary<string, string[]>? ProviderContracts,
        GatePolicyPaths? GatePolicies,
        string[]? ForbiddenProjectNames,
        Dictionary<string, string[]>? ForbiddenNamespaces,
        Dictionary<string, string[]>? ForbiddenSymbols,
        Dictionary<string, string[]>? ForbiddenText,
        NamespaceDeclarationRule[]? DeclarationNamespaces,
        ForbiddenDeclarationRule[]? ForbiddenDeclarations,
        PayloadRule[]? Payloads,
        string[]? EmbeddedAdapterNamespaces,
        Ring[]? TransitiveBoundaryRoles,
        Dictionary<string, string[]>? AllowedReferences,
        Dictionary<string, string[]>? AllowedPackages,
        Dictionary<string, string[]>? ForbiddenPackages,
        Dictionary<string, string[]>? ForbiddenDependencies,
        Dictionary<string, string[]>? ForbiddenDependencyOrigins,
        ForbiddenReferencesDocument? ForbiddenReferences,
        DeclarationRule[]? Declarations,
        bool? RequireRings
    );
}

public sealed record ReferenceScopeRule(Ring From, Ring To, string Ownership);

public sealed record NamespaceDeclarationRule(
    string Match,
    Ring[] MustLiveIn,
    string Namespace,
    string? Kind = null,
    string[]? Exceptions = null,
    Ring? MustImplement = null,
    bool MustImplementOwn = false
);

public sealed record ForbiddenDeclarationRule(
    string Match,
    Ring In,
    string? Kind = null,
    string[]? Exceptions = null
);

public sealed record PayloadRule(
    string Match,
    string[]? ForbiddenTypes = null,
    string[]? AllowedTypes = null,
    string[]? Exceptions = null
);

/// A type whose name matches `Match` has to be declared in `MustLiveIn`. The name is most of the
/// rule's input, because a naming convention is the only thing a codebase states out loud about
/// what a type is for — but `IUserRepository` and `UserRepository` belong in different rings and
/// differ only by being an interface, so `Kind` narrows the match where the name cannot.
/// `MustImplement` names the ring a base type has to be declared in, not a base type. "Every
/// repository class implements an interface declared in Domain" is a rule about where the
/// contract lives, and the codebase already says which contract by naming it in the base list.
public sealed record DeclarationRule(
    string Match,
    Ring MustLiveIn,
    string? Kind = null,
    string? Severity = null,
    Ring? MustImplement = null
);

/// One numbered rule of the rulebook a codebase is audited against, and what settles it here.
///
/// `Rules` empty means nothing this tool does settles it. `NotMeasured` set means what does run
/// reaches only part of the rule, and names the part it misses. Both are how a rulebook says out
/// loud that a clean result is not a complete one.
public sealed record RuleRef(
    string Ref,
    string[] Rules,
    Ring? Ring = null,
    bool? SameModule = null,
    string? NotMeasured = null,
    string? Text = null
);
