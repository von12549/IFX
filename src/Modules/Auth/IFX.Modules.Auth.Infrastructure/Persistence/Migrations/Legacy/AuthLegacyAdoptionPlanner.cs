using IFX.BuildingBlocks.EntityFrameworkCore.Migrations;

namespace IFX.Modules.Auth.Infrastructure.Persistence.Migrations.Legacy;

public static class AuthLegacyAdoptionPlanner
{
    public static AuthLegacyAdoptionPlan Create(
        IReadOnlyList<MigrationHistoryRow> sourceRows,
        IReadOnlyList<MigrationHistoryRow> targetRows,
        IReadOnlyCollection<string> currentMigrationIds,
        IReadOnlyCollection<string> knownForeignMigrationIds,
        string canonicalProductVersion,
        bool schemaFingerprintMatches,
        bool explicitAdoption)
    {
        ArgumentNullException.ThrowIfNull(sourceRows);
        ArgumentNullException.ThrowIfNull(targetRows);
        ArgumentNullException.ThrowIfNull(currentMigrationIds);
        ArgumentNullException.ThrowIfNull(knownForeignMigrationIds);

        var errors = new List<string>();
        ValidateRows("source", sourceRows, errors);
        ValidateRows("Auth target", targetRows, errors);
        if (string.IsNullOrWhiteSpace(canonicalProductVersion))
        {
            errors.Add("Canonical ProductVersion is required.");
        }

        var allowedIds = currentMigrationIds
            .Concat(AuthLegacyMigrationManifest.AllLegacyIds)
            .ToHashSet(StringComparer.Ordinal);
        var knownForeignIds = knownForeignMigrationIds.ToHashSet(StringComparer.Ordinal);
        foreach (var unknown in sourceRows.Select(row => row.MigrationId)
                     .Where(id => !allowedIds.Contains(id) && !knownForeignIds.Contains(id))
                     .Concat(targetRows.Select(row => row.MigrationId).Where(id => !allowedIds.Contains(id)))
                     .Distinct(StringComparer.Ordinal)
                     .Order(StringComparer.Ordinal))
        {
            errors.Add($"Auth history contains unknown MigrationId '{unknown}'.");
        }

        var targetIds = targetRows.Select(row => row.MigrationId).ToHashSet(StringComparer.Ordinal);
        var sourceIds = sourceRows.Select(row => row.MigrationId)
            .Where(allowedIds.Contains)
            .ToHashSet(StringComparer.Ordinal);
        var allIds = sourceIds.Concat(targetIds).ToHashSet(StringComparer.Ordinal);
        var hasCanonical = targetIds.Contains(AuthLegacyMigrationManifest.CanonicalInitialCreateId);
        var legacyIds = allIds.Intersect(AuthLegacyMigrationManifest.AllLegacyIds, StringComparer.Ordinal)
            .Order(StringComparer.Ordinal)
            .ToArray();

        var targetLegacyIds = targetIds
            .Intersect(AuthLegacyMigrationManifest.AllLegacyIds, StringComparer.Ordinal)
            .ToArray();
        if (hasCanonical && targetLegacyIds.Length == 0 && errors.Count == 0)
        {
            return new(
                AuthLegacyAdoptionClassification.AlreadyCanonical,
                [],
                null,
                []);
        }

        var isExactPreSquash = legacyIds.Length == AuthLegacyMigrationManifest.PreSquashMigrationIds.Count &&
                               AuthLegacyMigrationManifest.PreSquashMigrationIds.All(allIds.Contains) &&
                               !allIds.Contains(AuthLegacyMigrationManifest.IncorrectSquashAlias);
        var isExactAlias = legacyIds.Length == 1 &&
                           allIds.Contains(AuthLegacyMigrationManifest.IncorrectSquashAlias);
        var isEnsureCreated = allIds.Count == 0;

        if (!isExactPreSquash && !isExactAlias && !isEnsureCreated)
        {
            errors.Add("Auth legacy history is mixed or incomplete.");
        }

        if ((isExactPreSquash || isExactAlias || isEnsureCreated) && !schemaFingerprintMatches)
        {
            errors.Add("Auth schema fingerprint does not match the canonical baseline.");
        }

        if (errors.Count > 0)
        {
            return new(
                AuthLegacyAdoptionClassification.Invalid,
                [],
                null,
                errors.Distinct(StringComparer.Ordinal).Order(StringComparer.Ordinal).ToArray());
        }

        if (isEnsureCreated && !explicitAdoption)
        {
            return new(
                AuthLegacyAdoptionClassification.ExplicitAdoptionRequired,
                [],
                null,
                ["Auth schema has no recognized history; explicit adoption is required."]);
        }

        var classification = isExactPreSquash
            ? AuthLegacyAdoptionClassification.PreSquashHistory
            : isExactAlias
                ? AuthLegacyAdoptionClassification.IncorrectSquashAlias
                : AuthLegacyAdoptionClassification.EnsureCreatedAdoption;
        return new(
            classification,
            targetLegacyIds.Order(StringComparer.Ordinal).ToArray(),
            hasCanonical
                ? null
                : new MigrationHistoryRow(
                    AuthLegacyMigrationManifest.CanonicalInitialCreateId,
                    canonicalProductVersion),
            []);
    }

    private static void ValidateRows(
        string source,
        IReadOnlyList<MigrationHistoryRow> rows,
        ICollection<string> errors)
    {
        foreach (var duplicate in rows.GroupBy(row => row.MigrationId, StringComparer.Ordinal)
                     .Where(group => group.Count() > 1))
        {
            errors.Add($"{source} history contains duplicate MigrationId '{duplicate.Key}'.");
        }

        if (rows.Any(row => string.IsNullOrWhiteSpace(row.MigrationId) ||
                            string.IsNullOrWhiteSpace(row.ProductVersion)))
        {
            errors.Add($"{source} history contains an incomplete row.");
        }
    }
}
