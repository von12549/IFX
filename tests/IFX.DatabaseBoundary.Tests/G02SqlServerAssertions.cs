using FluentAssertions;
using IFX.DatabaseMigrator;
using Microsoft.Data.SqlClient;

namespace IFX.DatabaseBoundary.Tests;

/// <summary>
/// Reusable SQL Server conformance assertions for the Plan 02 E2/E4 Outbox and Inbox handoff.
/// </summary>
public static class G02SqlServerAssertions
{
    public static async Task AssertCurrentHistoriesAsync(
        string connectionString,
        MigrationManifest manifest,
        CancellationToken cancellationToken = default)
    {
        foreach (var module in manifest.Modules)
        {
            var actual = await QueryStringsAsync(
                connectionString,
                $"SELECT [MigrationId] FROM [{module.Schema}].[{module.HistoryTable}] ORDER BY [MigrationId];",
                cancellationToken);
            actual.Should().Equal(
                module.Migrations.Select(migration => migration.MigrationId),
                $"{module.ModuleName} history must contain exactly its owned migration catalog");
        }
    }

    public static async Task AssertNoCrossSchemaForeignKeysAsync(
        string connectionString,
        CancellationToken cancellationToken = default)
    {
        const string sql = """
            SELECT COUNT(*)
            FROM sys.foreign_keys fk
            JOIN sys.tables parent_table ON parent_table.object_id = fk.parent_object_id
            JOIN sys.schemas parent_schema ON parent_schema.schema_id = parent_table.schema_id
            JOIN sys.tables referenced_table ON referenced_table.object_id = fk.referenced_object_id
            JOIN sys.schemas referenced_schema ON referenced_schema.schema_id = referenced_table.schema_id
            WHERE parent_schema.name <> referenced_schema.name;
            """;
        await using var connection = new SqlConnection(connectionString);
        await connection.OpenAsync(cancellationToken);
        await using var command = connection.CreateCommand();
        command.CommandText = sql;
        var count = Convert.ToInt32(await command.ExecuteScalarAsync(cancellationToken));
        count.Should().Be(0, "module-owned schemas must not be coupled by database foreign keys");
    }

    private static async Task<IReadOnlyList<string>> QueryStringsAsync(
        string connectionString,
        string sql,
        CancellationToken cancellationToken)
    {
        await using var connection = new SqlConnection(connectionString);
        await connection.OpenAsync(cancellationToken);
        await using var command = connection.CreateCommand();
        command.CommandText = sql;
        await using var reader = await command.ExecuteReaderAsync(cancellationToken);
        var values = new List<string>();
        while (await reader.ReadAsync(cancellationToken)) values.Add(reader.GetString(0));
        return values;
    }
}
