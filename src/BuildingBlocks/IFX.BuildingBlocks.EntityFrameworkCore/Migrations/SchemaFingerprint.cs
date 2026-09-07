using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata;

namespace IFX.BuildingBlocks.EntityFrameworkCore.Migrations;

public sealed record SchemaFingerprint(string Schema, IReadOnlyList<TableFingerprint> Tables)
{
    public string Sha256()
    {
        var json = JsonSerializer.Serialize(this);
        return Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(json))).ToLowerInvariant();
    }
}

public sealed record TableFingerprint(
    string Name,
    IReadOnlyList<ColumnFingerprint> Columns,
    IReadOnlyList<KeyFingerprint> Keys,
    IReadOnlyList<ForeignKeyFingerprint> ForeignKeys,
    IReadOnlyList<IndexFingerprint> Indexes);

public sealed record ColumnFingerprint(string Name, string StoreType, bool IsNullable);

public sealed record KeyFingerprint(string Name, bool IsPrimary, IReadOnlyList<string> Columns);

public sealed record ForeignKeyFingerprint(
    string Name,
    IReadOnlyList<string> Columns,
    string PrincipalSchema,
    string PrincipalTable,
    IReadOnlyList<string> PrincipalColumns);

public sealed record IndexFingerprint(
    string Name,
    bool IsUnique,
    string? Filter,
    IReadOnlyList<string> Columns);

public sealed record SchemaFingerprintVerification(
    bool Matches,
    string ExpectedSha256,
    string ActualSha256,
    IReadOnlyList<string> Differences);

public static class SchemaFingerprintBuilder
{
    public static SchemaFingerprint FromModel(IModel model, string schema)
    {
        ArgumentNullException.ThrowIfNull(model);
        ArgumentException.ThrowIfNullOrWhiteSpace(schema);

        var tables = model.GetEntityTypes()
            .Where(entity => entity.GetTableName() is not null &&
                             string.Equals(entity.GetSchema(), schema, StringComparison.OrdinalIgnoreCase))
            .GroupBy(
                entity => entity.GetTableName()!,
                StringComparer.OrdinalIgnoreCase)
            .Select(group => CreateTable(group.Key, schema, group.ToArray()))
            .OrderBy(table => table.Name, StringComparer.OrdinalIgnoreCase)
            .ToArray();

        return new SchemaFingerprint(schema, tables);
    }

    private static TableFingerprint CreateTable(
        string table,
        string schema,
        IReadOnlyList<IEntityType> entities)
    {
        var store = StoreObjectIdentifier.Table(table, schema);
        var columns = entities
            .SelectMany(entity => entity.GetProperties())
            .Select(property => new ColumnFingerprint(
                property.GetColumnName(store)!,
                property.GetColumnType() ?? property.GetRelationalTypeMapping().StoreType,
                property.IsColumnNullable(store)))
            .GroupBy(column => column.Name, StringComparer.OrdinalIgnoreCase)
            .Select(group => group.First())
            .OrderBy(column => column.Name, StringComparer.OrdinalIgnoreCase)
            .ToArray();
        var keys = entities
            .SelectMany(entity => entity.GetKeys())
            .Select(key => new KeyFingerprint(
                key.GetName()!,
                key.IsPrimaryKey(),
                key.Properties.Select(property => property.GetColumnName(store)!).ToArray()))
            .GroupBy(key => key.Name, StringComparer.OrdinalIgnoreCase)
            .Select(group => group.First())
            .OrderBy(key => key.Name, StringComparer.OrdinalIgnoreCase)
            .ToArray();
        var foreignKeys = entities
            .SelectMany(entity => entity.GetForeignKeys())
            .Where(foreignKey =>
                !foreignKey.IsOwnership ||
                !string.Equals(
                    foreignKey.PrincipalEntityType.GetTableName(),
                    table,
                    StringComparison.OrdinalIgnoreCase) ||
                !string.Equals(
                    foreignKey.PrincipalEntityType.GetSchema(),
                    schema,
                    StringComparison.OrdinalIgnoreCase))
            .Select(foreignKey =>
            {
                var principalTable = foreignKey.PrincipalEntityType.GetTableName()!;
                var principalSchema = foreignKey.PrincipalEntityType.GetSchema()!;
                var principalStore = StoreObjectIdentifier.Table(principalTable, principalSchema);
                return new ForeignKeyFingerprint(
                    foreignKey.GetConstraintName()!,
                    foreignKey.Properties.Select(property => property.GetColumnName(store)!).ToArray(),
                    principalSchema,
                    principalTable,
                    foreignKey.PrincipalKey.Properties
                        .Select(property => property.GetColumnName(principalStore)!)
                        .ToArray());
            })
            .GroupBy(foreignKey => foreignKey.Name, StringComparer.OrdinalIgnoreCase)
            .Select(group => group.First())
            .OrderBy(foreignKey => foreignKey.Name, StringComparer.OrdinalIgnoreCase)
            .ToArray();
        var indexes = entities
            .SelectMany(entity => entity.GetIndexes())
            .Select(index => new IndexFingerprint(
                index.GetDatabaseName()!,
                index.IsUnique,
                SchemaFingerprintSql.NormalizeFilter(index.GetFilter()),
                index.Properties.Select(property => property.GetColumnName(store)!).ToArray()))
            .GroupBy(index => index.Name, StringComparer.OrdinalIgnoreCase)
            .Select(group => group.First())
            .OrderBy(index => index.Name, StringComparer.OrdinalIgnoreCase)
            .ToArray();

        return new TableFingerprint(table, columns, keys, foreignKeys, indexes);
    }
}

internal static class SchemaFingerprintSql
{
    public static string? NormalizeFilter(string? filter)
    {
        if (filter is null) return null;

        var builder = new StringBuilder(filter.Length);
        var inString = false;
        foreach (var character in filter)
        {
            if (character == '\'')
            {
                inString = !inString;
                builder.Append(character);
                continue;
            }

            if (!inString && (char.IsWhiteSpace(character) || character is '[' or ']' or '(' or ')'))
            {
                continue;
            }

            builder.Append(char.ToLowerInvariant(character));
        }

        return builder.ToString();
    }
}

public static class SchemaFingerprintComparer
{
    public static SchemaFingerprintVerification Verify(
        SchemaFingerprint expected,
        SchemaFingerprint actual)
    {
        ArgumentNullException.ThrowIfNull(expected);
        ArgumentNullException.ThrowIfNull(actual);

        var differences = new List<string>();
        if (!string.Equals(expected.Schema, actual.Schema, StringComparison.OrdinalIgnoreCase))
        {
            differences.Add($"Schema differs: expected '{expected.Schema}', actual '{actual.Schema}'.");
        }

        CompareNames("table", expected.Tables.Select(table => table.Name), actual.Tables.Select(table => table.Name), differences);
        foreach (var expectedTable in expected.Tables)
        {
            var actualTable = actual.Tables.SingleOrDefault(table =>
                string.Equals(table.Name, expectedTable.Name, StringComparison.OrdinalIgnoreCase));
            if (actualTable is null)
            {
                continue;
            }

            CompareItems(expectedTable.Name, "column", expectedTable.Columns, actualTable.Columns, item => item.Name, differences);
            CompareItems(expectedTable.Name, "key", expectedTable.Keys, actualTable.Keys, item => item.Name, differences);
            CompareItems(expectedTable.Name, "foreign key", expectedTable.ForeignKeys, actualTable.ForeignKeys, item => item.Name, differences);
            CompareItems(expectedTable.Name, "index", expectedTable.Indexes, actualTable.Indexes, item => item.Name, differences);
        }

        return new SchemaFingerprintVerification(
            differences.Count == 0,
            expected.Sha256(),
            actual.Sha256(),
            differences.Order(StringComparer.Ordinal).ToArray());
    }

    private static void CompareItems<T>(
        string table,
        string kind,
        IReadOnlyList<T> expected,
        IReadOnlyList<T> actual,
        Func<T, string> name,
        ICollection<string> differences)
    {
        CompareNames($"{table} {kind}", expected.Select(name), actual.Select(name), differences);
        foreach (var expectedItem in expected)
        {
            var actualItem = actual.SingleOrDefault(item =>
                string.Equals(name(item), name(expectedItem), StringComparison.OrdinalIgnoreCase));
            if (actualItem is not null &&
                !string.Equals(
                    JsonSerializer.Serialize(expectedItem),
                    JsonSerializer.Serialize(actualItem),
                    StringComparison.Ordinal))
            {
                differences.Add($"{table} {kind} '{name(expectedItem)}' definition differs.");
            }
        }
    }

    private static void CompareNames(
        string kind,
        IEnumerable<string> expected,
        IEnumerable<string> actual,
        ICollection<string> differences)
    {
        var expectedSet = expected.ToHashSet(StringComparer.OrdinalIgnoreCase);
        var actualSet = actual.ToHashSet(StringComparer.OrdinalIgnoreCase);
        foreach (var missing in expectedSet.Except(actualSet, StringComparer.OrdinalIgnoreCase).Order())
        {
            differences.Add($"Missing {kind} '{missing}'.");
        }

        foreach (var unexpected in actualSet.Except(expectedSet, StringComparer.OrdinalIgnoreCase).Order())
        {
            differences.Add($"Unexpected {kind} '{unexpected}'.");
        }
    }
}
