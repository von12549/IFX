using Microsoft.EntityFrameworkCore;

namespace IFX.DatabaseMigrator;

public static class MigrationManifestValidator
{
    public static IReadOnlyList<string> Validate(
        MigrationManifest manifest,
        IReadOnlyList<ModuleRuntime> runtimes,
        IReadOnlyDictionary<string, DbContext> contexts)
    {
        ArgumentNullException.ThrowIfNull(manifest);
        var errors = new List<string>();
        if (manifest.FormatVersion != 1)
        {
            errors.Add($"Unsupported manifest formatVersion '{manifest.FormatVersion}'.");
        }

        DuplicateErrors(manifest.Modules, module => module.ModuleName, "module", errors);
        DuplicateErrors(manifest.Modules, module => module.DbContext, "DbContext", errors);
        DuplicateErrors(manifest.Modules, module => module.Schema, "schema", errors);
        DuplicateErrors(manifest.Modules, module => module.ConnectionKey, "connection key", errors);
        foreach (var duplicate in manifest.Modules.GroupBy(module => module.Order).Where(group => group.Count() > 1))
        {
            errors.Add($"Duplicate module order '{duplicate.Key}'.");
        }

        var expectedNames = runtimes.Select(runtime => runtime.ModuleName).ToHashSet(StringComparer.Ordinal);
        var actualNames = manifest.Modules.Select(module => module.ModuleName).ToHashSet(StringComparer.Ordinal);
        foreach (var missing in expectedNames.Except(actualNames).Order())
        {
            errors.Add($"Manifest is missing module '{missing}'.");
        }
        foreach (var unexpected in actualNames.Except(expectedNames).Order())
        {
            errors.Add($"Manifest contains unexpected module '{unexpected}'.");
        }

        var allMigrationIds = manifest.Modules.SelectMany(module => module.Migrations);
        DuplicateErrors(allMigrationIds, migration => migration.MigrationId, "MigrationId", errors);

        foreach (var module in manifest.Modules)
        {
            var runtime = runtimes.SingleOrDefault(candidate => candidate.ModuleName == module.ModuleName);
            if (runtime is null)
            {
                continue;
            }
            if (module.DbContext != runtime.DbContextType.FullName ||
                module.Schema != runtime.Schema ||
                module.HistoryTable != runtime.HistoryTable ||
                module.ConnectionKey != runtime.ConnectionKey ||
                module.Order != runtime.Order)
            {
                errors.Add($"Manifest metadata does not match runtime module '{module.ModuleName}'.");
            }

            foreach (var dependency in module.DependsOn.Where(dependency => !actualNames.Contains(dependency)))
            {
                errors.Add($"Module '{module.ModuleName}' depends on missing module '{dependency}'.");
            }

            if (!contexts.TryGetValue(module.ModuleName, out var context))
            {
                errors.Add($"No runtime DbContext was created for '{module.ModuleName}'.");
                continue;
            }
            var assemblyRows = runtime.CurrentMigrationRows(context);
            var manifestRows = module.Migrations
                .Select(migration => (migration.MigrationId, migration.ProductVersion))
                .ToArray();
            if (!assemblyRows.Select(row => (row.MigrationId, row.ProductVersion)).SequenceEqual(manifestRows))
            {
                errors.Add($"Manifest migration catalog does not match the '{module.ModuleName}' assembly.");
            }
            if (module.Migrations.Any(migration =>
                    migration.SourceSha256.Length != 64 ||
                    migration.SourceSha256.Any(character => !Uri.IsHexDigit(character))))
            {
                errors.Add($"Module '{module.ModuleName}' contains an invalid source SHA-256.");
            }
        }

        DetectCycles(manifest.Modules, errors);
        return errors.Distinct(StringComparer.Ordinal).Order(StringComparer.Ordinal).ToArray();
    }

    private static void DuplicateErrors<T>(
        IEnumerable<T> items,
        Func<T, string> key,
        string kind,
        ICollection<string> errors)
    {
        foreach (var duplicate in items.GroupBy(key, StringComparer.OrdinalIgnoreCase).Where(group => group.Count() > 1))
        {
            errors.Add($"Duplicate {kind} '{duplicate.Key}'.");
        }
    }

    private static void DetectCycles(IReadOnlyList<ModuleManifest> modules, ICollection<string> errors)
    {
        var byName = modules.ToDictionary(module => module.ModuleName, StringComparer.Ordinal);
        var visiting = new HashSet<string>(StringComparer.Ordinal);
        var visited = new HashSet<string>(StringComparer.Ordinal);

        bool Visit(string module)
        {
            if (visiting.Contains(module)) return true;
            if (!visited.Add(module) || !byName.TryGetValue(module, out var value)) return false;
            visiting.Add(module);
            foreach (var dependency in value.DependsOn)
            {
                if (Visit(dependency)) return true;
            }
            visiting.Remove(module);
            return false;
        }

        if (modules.Any(module => Visit(module.ModuleName)))
        {
            errors.Add("Manifest dependency graph contains a cycle.");
        }
    }
}
