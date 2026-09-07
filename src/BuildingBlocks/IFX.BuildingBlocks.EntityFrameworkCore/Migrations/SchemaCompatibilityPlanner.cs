namespace IFX.BuildingBlocks.EntityFrameworkCore.Migrations;

public static class SchemaCompatibilityPlanner
{
    public static ModuleSchemaCompatibility Evaluate(
        ModuleSchemaRequirement requirement,
        IReadOnlyCollection<string> appliedMigrationIds)
    {
        ArgumentNullException.ThrowIfNull(requirement);
        ArgumentNullException.ThrowIfNull(appliedMigrationIds);

        var applied = appliedMigrationIds.ToHashSet(StringComparer.Ordinal);
        if (applied.Count != appliedMigrationIds.Count)
        {
            return Result(false, "duplicate-history", requirement, applied, [], []);
        }

        var required = requirement.RequiredMigrationIds.ToHashSet(StringComparer.Ordinal);
        var missing = required.Except(applied).Order(StringComparer.Ordinal).ToArray();
        var additional = applied.Except(required).Order(StringComparer.Ordinal).ToArray();
        if (missing.Length > 0)
        {
            return Result(false, "required-migration-missing", requirement, applied, missing, additional);
        }
        var compatibleAdditional = requirement.CompatibleAdditionalMigrationIds.ToHashSet(StringComparer.Ordinal);
        var unsupportedAdditional = additional.Except(compatibleAdditional).Order(StringComparer.Ordinal).ToArray();
        if (unsupportedAdditional.Length > 0)
        {
            return Result(false, "additional-migration-not-compatible", requirement, applied, missing, additional);
        }

        return Result(true, additional.Length == 0 ? "required-version" : "newer-expand-compatible", requirement, applied, missing, additional);
    }

    public static IReadOnlyList<string> ValidateManifest(ReleaseSchemaManifest manifest)
    {
        var errors = new List<string>();
        if (manifest.FormatVersion != 1) errors.Add($"Unsupported formatVersion '{manifest.FormatVersion}'.");
        if (string.IsNullOrWhiteSpace(manifest.ReleaseVersion)) errors.Add("ReleaseVersion is required.");
        if (manifest.MigrationCatalogSha256.Length != 64 ||
            manifest.MigrationCatalogSha256.Any(character => !Uri.IsHexDigit(character)))
        {
            errors.Add("MigrationCatalogSha256 must be a SHA-256 value.");
        }

        foreach (var duplicate in manifest.Modules.GroupBy(module => module.ModuleName, StringComparer.OrdinalIgnoreCase).Where(group => group.Count() > 1))
        {
            errors.Add($"Duplicate module '{duplicate.Key}'.");
        }
        foreach (var module in manifest.Modules)
        {
            if (!IsIdentifier(module.Schema) || !IsIdentifier(module.HistoryTable))
            {
                errors.Add($"Module '{module.ModuleName}' contains an invalid SQL identifier.");
            }
            if (module.RequiredMigrationIds.Count == 0)
            {
                errors.Add($"Module '{module.ModuleName}' has no required migrations.");
            }
            else if (module.RequiredMigrationIds.Distinct(StringComparer.Ordinal).Count() != module.RequiredMigrationIds.Count)
            {
                errors.Add($"Module '{module.ModuleName}' contains duplicate required migrations.");
            }
            else if (module.CompatibleAdditionalMigrationIds.Distinct(StringComparer.Ordinal).Count() != module.CompatibleAdditionalMigrationIds.Count ||
                     module.CompatibleAdditionalMigrationIds.Intersect(module.RequiredMigrationIds, StringComparer.Ordinal).Any())
            {
                errors.Add($"Module '{module.ModuleName}' contains an invalid compatible migration catalog.");
            }
            else if (module.RequiredMigrationIds[^1] != module.RequiredMigrationId)
            {
                errors.Add($"Module '{module.ModuleName}' required version does not match its catalog tail.");
            }
        }
        return errors.Order(StringComparer.Ordinal).ToArray();
    }

    private static ModuleSchemaCompatibility Result(
        bool compatible,
        string code,
        ModuleSchemaRequirement requirement,
        IReadOnlySet<string> applied,
        IReadOnlyList<string> missing,
        IReadOnlyList<string> additional) =>
        new(
            requirement.ModuleName,
            compatible,
            code,
            requirement.RequiredMigrationIds.LastOrDefault(id => applied.Contains(id)),
            missing,
            additional);

    private static bool IsIdentifier(string value) =>
        !string.IsNullOrWhiteSpace(value) &&
        value.Length <= 128 &&
        value.All(character => char.IsAsciiLetterOrDigit(character) || character == '_');
}
