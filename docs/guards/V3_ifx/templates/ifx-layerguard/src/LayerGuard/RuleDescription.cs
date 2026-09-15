using System.Text;

namespace LayerGuard;

public static class RuleDescription
{
    private static readonly Ring[] Order =
    [
        Ring.Domain,
        Ring.Application,
        Ring.Presentation,
        Ring.Infrastructure,
        Ring.Client,
        Ring.Runtime,
        Ring.Composition,
        Ring.RuntimeHost,
    ];

    public static string Render(Ruleset ruleset)
    {
        var text = new StringBuilder();

        text.AppendLine("# Rules in force");
        text.AppendLine();
        text.AppendLine($"Source: {ruleset.Source}");
        text.AppendLine();

        text.AppendLine("## Which project counts as which layer");
        text.AppendLine();
        text.AppendLine("| layer | project name matches |");
        text.AppendLine("| --- | --- |");
        foreach (var ring in Order)
        {
            var patterns = ruleset.RingPatterns.TryGetValue(ring, out var found) ? found : [];
            text.AppendLine($"| {ring} | {string.Join(", ", patterns.Select(p => $"`{p}`"))} |");
        }
        text.AppendLine();
        text.AppendLine("A project matching none of these is outside the check. It is listed and never ruled on.");
        text.AppendLine();

        text.AppendLine("## Which layer may depend on which");
        text.AppendLine();
        text.Append("| depends on → |");
        foreach (var ring in Order)
            text.Append($" {ring} |");
        text.AppendLine();
        text.Append("| --- |");
        foreach (var _ in Order)
            text.Append(" --- |");
        text.AppendLine();

        foreach (var from in Order)
        {
            text.Append($"| **{from}** |");
            foreach (var to in Order)
                text.Append(from == to ? " — |" : ruleset.Allows(from, to) ? " allowed |" : " **refused** |");
            text.AppendLine();
        }
        text.AppendLine();

        text.AppendLine("The table is applied twice: to what the project files reference, and to what the");
        text.AppendLine("source files import.");
        text.AppendLine();
        text.AppendLine("- **direct** — the project names the other one in its own project file.");
        text.AppendLine(
            "- **transitive** — a project it references passes the other one along. .NET forwards project "
                + "references by default; `PrivateAssets=\"all\"` on the offending reference stops it."
        );
        text.AppendLine(
            "- **import** — a source file names the other layer's namespace. An import inside a branch "
                + "the preprocessor turned off is reported and marked, because it is real in whatever "
                + "configuration turns that branch on."
        );
        text.AppendLine();

        AppendRulebook(text, ruleset);
        AppendAllowedReferences(text, ruleset);
        AppendPackages(text, ruleset);
        AppendForbiddenPackages(text, ruleset);
        AppendForbidden(text, ruleset);
        AppendDependencies(text, ruleset);
        AppendDeclarations(text, ruleset);
        AppendStructure(text, ruleset);

        AppendSeverities(text, ruleset);

        text.AppendLine("## What nothing here looks at");
        text.AppendLine();
        text.AppendLine("- type names written out in full in code, with no import line");
        text.AppendLine(
            "- which project a name really binds to — namespaces are matched against project names, "
                + "not resolved by a compiler"
        );
        text.AppendLine("- method bodies, and any use of a type that needs no import");
        text.AppendLine("- anything inside a project that matches no layer");

        return text.ToString();
    }

    private static void AppendRulebook(StringBuilder text, Ruleset ruleset)
    {
        if (ruleset.RuleRefs.Count == 0)
            return;

        text.AppendLine("## The numbered rules this codebase is audited against");
        text.AppendLine();
        text.AppendLine("| rule | settled by | not measured |");
        text.AppendLine("| --- | --- | --- |");
        foreach (var entry in ruleset.RuleRefs)
        {
            var by = entry.Rules.Length == 0
                ? "**nothing**"
                : string.Join(", ", entry.Rules.Select(rule => $"`{rule}`"));
            text.AppendLine($"| **{entry.Ref}** {entry.Text} | {by} | {entry.NotMeasured ?? "—"} |");
        }
        text.AppendLine();
        text.AppendLine("Every finding carries the rule it answers to, so nothing downstream has to work the");
        text.AppendLine("mapping out again. The last column is what a clean result does NOT prove.");
        text.AppendLine();
    }

    private static void AppendSeverities(StringBuilder text, Ruleset ruleset)
    {
        if (ruleset.Severities.Count == 0)
            return;

        text.AppendLine("## How loudly each rule speaks");
        text.AppendLine();
        text.AppendLine("| rule | severity |");
        text.AppendLine("| --- | --- |");
        foreach (var (ruleId, severity) in ruleset.Severities.OrderBy(pair => pair.Key, StringComparer.Ordinal))
            text.AppendLine($"| `{ruleId}` | {severity} |");
        text.AppendLine();
        text.AppendLine("Any rule not named here reports at the level it carries. An entry under");
        text.AppendLine("`declarations` that names its own severity keeps it: that is the narrower claim.");
        text.AppendLine();
    }

    private static void AppendAllowedReferences(StringBuilder text, Ruleset ruleset)
    {
        if (ruleset.AllowedReferences.Count == 0)
            return;

        text.AppendLine("## Which projects a layer may name");
        text.AppendLine();
        text.AppendLine("| layer | may name only |");
        text.AppendLine("| --- | --- |");
        foreach (var ring in Order)
        {
            var allowed = ruleset.ReferencesAllowedIn(ring);
            if (allowed is null)
                continue;
            var wording =
                allowed.Length == 0
                    ? "**no other project at all**"
                    : string.Join(", ", allowed.Select(pattern => $"`{pattern}`"));
            text.AppendLine($"| {ring} | {wording} |");
        }
        text.AppendLine();
        text.AppendLine("Read off the references the project writes in its own file, not off what it can");
        text.AppendLine("reach. A pair of layers the direction table already refuses is left to that table, so");
        text.AppendLine("one mistake is one finding. A layer absent from this list may name anything.");
        text.AppendLine();
    }

    private static void AppendPackages(StringBuilder text, Ruleset ruleset)
    {
        text.AppendLine("## Which packages a layer may hold");
        text.AppendLine();
        if (ruleset.AllowedPackages.Count == 0)
        {
            text.AppendLine("Not stated, so no package is judged. A layer with no rule here is not checked,");
            text.AppendLine("which is not the same as being clean.");
            text.AppendLine();
            return;
        }

        text.AppendLine("| layer | may hold |");
        text.AppendLine("| --- | --- |");
        foreach (var ring in Order)
        {
            var allowed = ruleset.PackagesAllowedIn(ring);
            var wording = allowed switch
            {
                null => "*not stated — not checked*",
                { Length: 0 } => "**nothing at all**",
                _ => string.Join(", ", allowed.Select(pattern => $"`{pattern}`")),
            };
            text.AppendLine($"| {ring} | {wording} |");
        }
        text.AppendLine();
        text.AppendLine("Applied to the packages a project declares, and to imported namespaces that no");
        text.AppendLine("project the run loaded declares. A namespace is not a package id, so that second");
        text.AppendLine("reading is a match on the name, not a resolved fact.");
        text.AppendLine();
    }

    private static void AppendForbiddenPackages(StringBuilder text, Ruleset ruleset)
    {
        if (ruleset.ForbiddenPackages.Count == 0)
            return;

        text.AppendLine("## Which packages a layer may never hold");
        text.AppendLine();
        text.AppendLine("| layer | may never hold |");
        text.AppendLine("| --- | --- |");
        foreach (var ring in Order)
        {
            if (!ruleset.ForbiddenPackages.TryGetValue(ring, out var patterns))
                continue;
            text.AppendLine($"| {ring} | {string.Join(", ", patterns.Select(p => $"`{p}`"))} |");
        }
        text.AppendLine();
        text.AppendLine("Read before the allow-list above, and applied to both what a project declares and");
        text.AppendLine("what its files import. A layer absent from this table is not checked here.");
        text.AppendLine();
    }

    private static void AppendForbidden(StringBuilder text, Ruleset ruleset)
    {
        if (ruleset.ForbiddenInSameModule.Length == 0 && ruleset.ForbiddenByRing.Count == 0)
            return;

        text.AppendLine("## Projects that may never be referenced");
        text.AppendLine();
        text.AppendLine("The direction table says nothing about a project matching no layer. These do.");
        text.AppendLine();
        if (ruleset.ForbiddenInSameModule.Length > 0)
            text.AppendLine(
                "- inside its own module, no project may reference: "
                    + string.Join(", ", ruleset.ForbiddenInSameModule.Select(p => $"`{p}`"))
            );
        foreach (var (ring, patterns) in ruleset.ForbiddenByRing)
            text.AppendLine($"- {ring} may never reference: {string.Join(", ", patterns.Select(p => $"`{p}`"))}");
        text.AppendLine();
    }

    private static void AppendDependencies(StringBuilder text, Ruleset ruleset)
    {
        if (ruleset.ForbiddenDependencies.Count == 0 && ruleset.ForbiddenDependencyOrigins.Count == 0)
            return;

        text.AppendLine("## What a layer may never be handed to hold");
        text.AppendLine();
        text.AppendLine("| layer | may not take |");
        text.AppendLine("| --- | --- |");
        foreach (var ring in Order)
        {
            if (!ruleset.ForbiddenDependencies.TryGetValue(ring, out var patterns))
                continue;
            text.AppendLine($"| {ring} | {string.Join(", ", patterns.Select(p => $"`{p}`"))} |");
        }
        text.AppendLine();
        foreach (var ring in Order)
        {
            if (!ruleset.ForbiddenDependencyOrigins.TryGetValue(ring, out var origins))
                continue;
            text.AppendLine(
                $"| {ring} | anything declared in {string.Join(", ", origins.Select(r => r.ToString()))} |"
            );
        }
        text.AppendLine();
        text.AppendLine("Read off constructor parameters, primary and declared alike, and matched against every");
        text.AppendLine("name written inside the parameter's type — so wrapping one in a list or marking it");
        text.AppendLine("nullable does not hide it. What a method body then does with the thing is not looked");
        text.AppendLine("at: this catches the dependency, never the call.");
        text.AppendLine();
        if (ruleset.ForbiddenDependencyOrigins.Count > 0)
        {
            text.AppendLine("A row naming a layer rather than a pattern asks where the type was declared, not what");
            text.AppendLine("it is called. Where the layer being judged declares a type of the same name itself,");
            text.AppendLine("the name binds at home and nothing is reported.");
            text.AppendLine();
        }
    }

    private static void AppendDeclarations(StringBuilder text, Ruleset ruleset)
    {
        if (ruleset.Declarations.Count == 0)
            return;

        text.AppendLine("## Where a type has to be declared");
        text.AppendLine();
        text.AppendLine("| a type named | of kind | must be declared in | answering to a contract in | severity |");
        text.AppendLine("| --- | --- | --- | --- | --- |");
        foreach (var rule in ruleset.Declarations)
            text.AppendLine(
                $"| `{rule.Match}` | {rule.Kind ?? "any"} | {rule.MustLiveIn} | "
                    + $"{rule.MustImplement?.ToString() ?? "—"} | {rule.Severity ?? "breaks"} |"
            );
        text.AppendLine();
        text.AppendLine("Matched on the type's own name, which is the only thing a codebase states out loud");
        text.AppendLine("about what a type is for.");
        text.AppendLine();
        if (ruleset.Declarations.Any(rule => rule.MustImplement is not null))
        {
            text.AppendLine("The last column is satisfied when the type names a base type that some project in");
            text.AppendLine("that layer declares under the same simple name. A type naming no base type at all");
            text.AppendLine("answers to nothing and never satisfies it. Names are matched, not resolved, so two");
            text.AppendLine("types sharing a simple name in different layers both count.");
            text.AppendLine();
        }
    }

    private static void AppendStructure(StringBuilder text, Ruleset ruleset)
    {
        if (!ruleset.RequireRings)
            return;

        text.AppendLine("## Every module holds every layer");
        text.AppendLine();
        text.AppendLine("A module missing one of the layers above is reported. Nothing points the wrong way");
        text.AppendLine("when a layer is simply absent, so no other rule would ever mention it.");
        text.AppendLine();
    }
}
