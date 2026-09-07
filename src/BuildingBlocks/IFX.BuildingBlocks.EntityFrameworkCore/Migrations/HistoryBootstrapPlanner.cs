using System.Text.RegularExpressions;

namespace IFX.BuildingBlocks.EntityFrameworkCore.Migrations;

public static partial class HistoryBootstrapPlanner
{
    public static HistoryBootstrapPlan Create(
        IReadOnlyList<ModuleMigrationCatalog> catalogs,
        HistoryBootstrapSnapshot snapshot)
    {
        ArgumentNullException.ThrowIfNull(catalogs);
        ArgumentNullException.ThrowIfNull(snapshot);

        var errors = ValidateCatalogs(catalogs).ToList();
        var orderedCatalogs = catalogs.OrderBy(catalog => catalog.Order).ToArray();
        var migrationOwners = orderedCatalogs
            .SelectMany(catalog => catalog.MigrationIds.Select(id => (Id: id, Catalog: catalog)))
            .GroupBy(item => item.Id, StringComparer.Ordinal)
            .Where(group => group.Count() == 1)
            .ToDictionary(group => group.Key, group => group.Single().Catalog, StringComparer.Ordinal);

        ValidateRows("shared history", snapshot.SharedHistory, errors);
        foreach (var row in snapshot.SharedHistory)
        {
            if (!migrationOwners.ContainsKey(row.MigrationId))
            {
                errors.Add($"Shared history contains unknown MigrationId '{row.MigrationId}'.");
            }
        }

        var isFresh = !snapshot.SharedHistoryExists &&
                      snapshot.SharedHistory.Count == 0 &&
                      orderedCatalogs.All(catalog =>
                          GetHistory(snapshot, catalog).Exists is false &&
                          GetHistory(snapshot, catalog).Rows.Count == 0 &&
                          GetSchemaState(snapshot, catalog) == ModuleSchemaState.Absent);
        if (isFresh && errors.Count == 0)
        {
            return new HistoryBootstrapPlan(
                HistoryBootstrapClassification.Fresh,
                orderedCatalogs.Select(catalog => new ModuleHistoryBootstrapPlan(
                    catalog.Module,
                    catalog.Schema,
                    false,
                    [],
                    catalog.MigrationIds.ToArray())).ToArray(),
                []);
        }

        var plans = new List<ModuleHistoryBootstrapPlan>();
        var adoptionRequired = false;
        foreach (var catalog in orderedCatalogs)
        {
            var history = GetHistory(snapshot, catalog);
            var schemaState = GetSchemaState(snapshot, catalog);
            ValidateRows($"{catalog.Module} history", history.Rows, errors);

            var ownedIds = catalog.MigrationIds.ToHashSet(StringComparer.Ordinal);
            foreach (var row in history.Rows.Where(row => !ownedIds.Contains(row.MigrationId)))
            {
                errors.Add(
                    $"{catalog.Module} history contains foreign or unknown MigrationId '{row.MigrationId}'.");
            }

            if (schemaState == ModuleSchemaState.Partial)
            {
                errors.Add($"{catalog.Module} schema fingerprint is partial.");
            }

            var sharedRows = snapshot.SharedHistory
                .Where(row => ownedIds.Contains(row.MigrationId))
                .OrderBy(row => row.MigrationId, StringComparer.Ordinal)
                .ToArray();

            if ((sharedRows.Length > 0 || history.Rows.Count > 0) && schemaState != ModuleSchemaState.Complete)
            {
                errors.Add(
                    $"{catalog.Module} history claims applied migrations but its schema fingerprint is not complete.");
            }

            if (history.Rows.Count == 0 && sharedRows.Length == 0 && schemaState == ModuleSchemaState.Complete)
            {
                adoptionRequired = true;
                errors.Add(
                    $"{catalog.Module} has a complete schema without recognized history; explicit adoption is required.");
            }

            var existing = history.Rows
                .Where(row => !string.IsNullOrWhiteSpace(row.MigrationId))
                .GroupBy(row => row.MigrationId, StringComparer.Ordinal)
                .ToDictionary(group => group.Key, group => group.First(), StringComparer.Ordinal);
            foreach (var sharedRow in sharedRows)
            {
                if (existing.TryGetValue(sharedRow.MigrationId, out var targetRow) &&
                    !string.Equals(targetRow.ProductVersion, sharedRow.ProductVersion, StringComparison.Ordinal))
                {
                    errors.Add(
                        $"{catalog.Module} history ProductVersion conflicts for '{sharedRow.MigrationId}'.");
                }
            }

            var rowsToInsert = sharedRows
                .Where(row => !existing.ContainsKey(row.MigrationId))
                .ToArray();
            var effectiveAppliedIds = existing.Keys
                .Concat(sharedRows.Select(row => row.MigrationId))
                .ToHashSet(StringComparer.Ordinal);
            var pendingMigrationIds = catalog.MigrationIds
                .Where(id => !effectiveAppliedIds.Contains(id))
                .ToArray();
            plans.Add(new ModuleHistoryBootstrapPlan(
                catalog.Module,
                catalog.Schema,
                !history.Exists && sharedRows.Length > 0,
                rowsToInsert,
                pendingMigrationIds));
        }

        var classification = errors.Count > 0
            ? adoptionRequired && errors.All(error => error.Contains("explicit adoption", StringComparison.Ordinal))
                ? HistoryBootstrapClassification.ExplicitAdoptionRequired
                : HistoryBootstrapClassification.Invalid
            : plans.Any(plan => plan.CreateHistoryTable || plan.RowsToInsert.Count > 0)
                ? HistoryBootstrapClassification.CurrentSharedHistory
                : HistoryBootstrapClassification.AlreadyBootstrapped;

        return new HistoryBootstrapPlan(
            classification,
            plans,
            errors.Distinct(StringComparer.Ordinal).Order(StringComparer.Ordinal).ToArray());
    }

    private static IEnumerable<string> ValidateCatalogs(IReadOnlyList<ModuleMigrationCatalog> catalogs)
    {
        if (catalogs.Count == 0)
        {
            yield return "At least one module migration catalog is required.";
            yield break;
        }

        foreach (var catalog in catalogs)
        {
            if (string.IsNullOrWhiteSpace(catalog.Module) || string.IsNullOrWhiteSpace(catalog.Schema) ||
                !SqlIdentifier().IsMatch(catalog.Schema))
            {
                yield return "Every module catalog requires a valid module name and SQL schema identifier.";
            }

            if (catalog.MigrationIds.Count == 0)
            {
                yield return $"{catalog.Module} has an empty migration catalog.";
            }

            if (catalog.RequiredTables.Count == 0)
            {
                yield return $"{catalog.Module} has an empty schema fingerprint.";
            }

            foreach (var table in catalog.RequiredTables.Where(table =>
                         string.IsNullOrWhiteSpace(table) || !SqlIdentifier().IsMatch(table)))
            {
                yield return $"{catalog.Module} schema fingerprint contains invalid table '{table}'.";
            }

            foreach (var duplicate in catalog.RequiredTables
                         .GroupBy(table => table, StringComparer.OrdinalIgnoreCase)
                         .Where(group => group.Count() > 1))
            {
                yield return $"{catalog.Module} schema fingerprint contains duplicate table '{duplicate.Key}'.";
            }
        }

        foreach (var duplicate in catalogs.GroupBy(catalog => catalog.Module, StringComparer.OrdinalIgnoreCase)
                     .Where(group => group.Count() > 1))
        {
            yield return $"Duplicate module '{duplicate.Key}'.";
        }

        foreach (var duplicate in catalogs.GroupBy(catalog => catalog.Schema, StringComparer.OrdinalIgnoreCase)
                     .Where(group => group.Count() > 1))
        {
            yield return $"Duplicate schema '{duplicate.Key}'.";
        }

        foreach (var duplicate in catalogs.GroupBy(catalog => catalog.Order)
                     .Where(group => group.Count() > 1))
        {
            yield return $"Duplicate module order '{duplicate.Key}'.";
        }

        foreach (var duplicate in catalogs.SelectMany(catalog => catalog.MigrationIds)
                     .GroupBy(id => id, StringComparer.Ordinal)
                     .Where(group => group.Count() > 1))
        {
            yield return $"MigrationId '{duplicate.Key}' has duplicate ownership.";
        }
    }

    private static void ValidateRows(
        string source,
        IReadOnlyList<MigrationHistoryRow> rows,
        ICollection<string> errors)
    {
        foreach (var duplicate in rows.GroupBy(row => row.MigrationId, StringComparer.Ordinal)
                     .Where(group => group.Count() > 1))
        {
            errors.Add($"{source} contains duplicate MigrationId '{duplicate.Key}'.");
        }

        foreach (var row in rows.Where(row =>
                     string.IsNullOrWhiteSpace(row.MigrationId) ||
                     string.IsNullOrWhiteSpace(row.ProductVersion)))
        {
            errors.Add($"{source} contains a row with a missing MigrationId or ProductVersion.");
        }
    }

    private static ModuleHistoryState GetHistory(
        HistoryBootstrapSnapshot snapshot,
        ModuleMigrationCatalog catalog) =>
        snapshot.ModuleHistories.TryGetValue(catalog.Module, out var history)
            ? history
            : new ModuleHistoryState(false, []);

    private static ModuleSchemaState GetSchemaState(
        HistoryBootstrapSnapshot snapshot,
        ModuleMigrationCatalog catalog) =>
        snapshot.ModuleSchemas.TryGetValue(catalog.Module, out var state)
            ? state
            : ModuleSchemaState.Absent;

    [GeneratedRegex("^[A-Za-z][A-Za-z0-9_]*$", RegexOptions.CultureInvariant)]
    private static partial Regex SqlIdentifier();
}
