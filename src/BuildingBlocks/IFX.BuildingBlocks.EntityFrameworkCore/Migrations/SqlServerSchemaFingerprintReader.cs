using System.Data.Common;

namespace IFX.BuildingBlocks.EntityFrameworkCore.Migrations;

public static class SqlServerSchemaFingerprintReader
{
    public static async Task<SchemaFingerprint> ReadAsync(
        DbConnection connection,
        DbTransaction? transaction,
        string schema,
        CancellationToken cancellationToken = default)
    {
        ArgumentNullException.ThrowIfNull(connection);
        ArgumentException.ThrowIfNullOrWhiteSpace(schema);

        var tables = new Dictionary<string, MutableTable>(StringComparer.OrdinalIgnoreCase);
        await ReadColumnsAsync(connection, transaction, schema, tables, cancellationToken);
        await ReadKeysAsync(connection, transaction, schema, tables, cancellationToken);
        await ReadForeignKeysAsync(connection, transaction, schema, tables, cancellationToken);
        await ReadIndexesAsync(connection, transaction, schema, tables, cancellationToken);

        return new SchemaFingerprint(
            schema,
            tables.Values
                .Select(table => table.Build())
                .OrderBy(table => table.Name, StringComparer.OrdinalIgnoreCase)
                .ToArray());
    }

    private static async Task ReadColumnsAsync(
        DbConnection connection,
        DbTransaction? transaction,
        string schema,
        IDictionary<string, MutableTable> tables,
        CancellationToken cancellationToken)
    {
        const string sql = """
            SELECT t.name, c.name, ty.name, c.max_length, c.precision, c.scale, c.is_nullable
            FROM sys.tables t
            JOIN sys.schemas s ON s.schema_id = t.schema_id
            JOIN sys.columns c ON c.object_id = t.object_id
            JOIN sys.types ty ON ty.user_type_id = c.user_type_id
            WHERE s.name = @schema AND t.name <> @history
            ORDER BY t.name, c.column_id;
            """;
        await using var command = Command(connection, transaction, sql);
        Parameter(command, "@schema", schema);
        Parameter(command, "@history", SqlServerHistoryBootstrapper.HistoryTable);
        await using var reader = await command.ExecuteReaderAsync(cancellationToken);
        while (await reader.ReadAsync(cancellationToken))
        {
            var table = GetTable(tables, reader.GetString(0));
            table.Columns.Add(new ColumnFingerprint(
                reader.GetString(1),
                StoreType(
                    reader.GetString(2),
                    reader.GetInt16(3),
                    reader.GetByte(4),
                    reader.GetByte(5)),
                reader.GetBoolean(6)));
        }
    }

    private static async Task ReadKeysAsync(
        DbConnection connection,
        DbTransaction? transaction,
        string schema,
        IDictionary<string, MutableTable> tables,
        CancellationToken cancellationToken)
    {
        const string sql = """
            SELECT t.name, kc.name, kc.type, c.name
            FROM sys.key_constraints kc
            JOIN sys.tables t ON t.object_id = kc.parent_object_id
            JOIN sys.schemas s ON s.schema_id = t.schema_id
            JOIN sys.index_columns ic ON ic.object_id = t.object_id AND ic.index_id = kc.unique_index_id
            JOIN sys.columns c ON c.object_id = t.object_id AND c.column_id = ic.column_id
            WHERE s.name = @schema
            ORDER BY t.name, kc.name, ic.key_ordinal;
            """;
        await using var command = Command(connection, transaction, sql);
        Parameter(command, "@schema", schema);
        await using var reader = await command.ExecuteReaderAsync(cancellationToken);
        var groups = new Dictionary<(string Table, string Name, bool Primary), List<string>>();
        while (await reader.ReadAsync(cancellationToken))
        {
            var key = (reader.GetString(0), reader.GetString(1), reader.GetString(2) == "PK");
            if (!groups.TryGetValue(key, out var columns))
            {
                columns = [];
                groups[key] = columns;
            }
            columns.Add(reader.GetString(3));
        }

        foreach (var pair in groups)
        {
            GetTable(tables, pair.Key.Table).Keys.Add(
                new KeyFingerprint(pair.Key.Name, pair.Key.Primary, pair.Value));
        }
    }

    private static async Task ReadForeignKeysAsync(
        DbConnection connection,
        DbTransaction? transaction,
        string schema,
        IDictionary<string, MutableTable> tables,
        CancellationToken cancellationToken)
    {
        const string sql = """
            SELECT pt.name, fk.name, pc.name, ps.name, rt.name, rc.name
            FROM sys.foreign_keys fk
            JOIN sys.tables pt ON pt.object_id = fk.parent_object_id
            JOIN sys.schemas pts ON pts.schema_id = pt.schema_id
            JOIN sys.foreign_key_columns fkc ON fkc.constraint_object_id = fk.object_id
            JOIN sys.columns pc ON pc.object_id = pt.object_id AND pc.column_id = fkc.parent_column_id
            JOIN sys.tables rt ON rt.object_id = fk.referenced_object_id
            JOIN sys.schemas ps ON ps.schema_id = rt.schema_id
            JOIN sys.columns rc ON rc.object_id = rt.object_id AND rc.column_id = fkc.referenced_column_id
            WHERE pts.name = @schema
            ORDER BY pt.name, fk.name, fkc.constraint_column_id;
            """;
        await using var command = Command(connection, transaction, sql);
        Parameter(command, "@schema", schema);
        await using var reader = await command.ExecuteReaderAsync(cancellationToken);
        var groups = new Dictionary<(string Table, string Name, string PrincipalSchema, string PrincipalTable),
            (List<string> Columns, List<string> PrincipalColumns)>();
        while (await reader.ReadAsync(cancellationToken))
        {
            var key = (reader.GetString(0), reader.GetString(1), reader.GetString(3), reader.GetString(4));
            if (!groups.TryGetValue(key, out var columns))
            {
                columns = ([], []);
                groups[key] = columns;
            }
            columns.Columns.Add(reader.GetString(2));
            columns.PrincipalColumns.Add(reader.GetString(5));
        }

        foreach (var pair in groups)
        {
            GetTable(tables, pair.Key.Table).ForeignKeys.Add(new ForeignKeyFingerprint(
                pair.Key.Name,
                pair.Value.Columns,
                pair.Key.PrincipalSchema,
                pair.Key.PrincipalTable,
                pair.Value.PrincipalColumns));
        }
    }

    private static async Task ReadIndexesAsync(
        DbConnection connection,
        DbTransaction? transaction,
        string schema,
        IDictionary<string, MutableTable> tables,
        CancellationToken cancellationToken)
    {
        const string sql = """
            SELECT t.name, i.name, i.is_unique, i.filter_definition, c.name
            FROM sys.indexes i
            JOIN sys.tables t ON t.object_id = i.object_id
            JOIN sys.schemas s ON s.schema_id = t.schema_id
            JOIN sys.index_columns ic ON ic.object_id = i.object_id AND ic.index_id = i.index_id
            JOIN sys.columns c ON c.object_id = t.object_id AND c.column_id = ic.column_id
            WHERE s.name = @schema
              AND i.is_primary_key = 0
              AND i.is_unique_constraint = 0
              AND i.is_hypothetical = 0
              AND i.name IS NOT NULL
              AND ic.is_included_column = 0
            ORDER BY t.name, i.name, ic.key_ordinal;
            """;
        await using var command = Command(connection, transaction, sql);
        Parameter(command, "@schema", schema);
        await using var reader = await command.ExecuteReaderAsync(cancellationToken);
        var groups = new Dictionary<(string Table, string Name, bool Unique, string? Filter), List<string>>();
        while (await reader.ReadAsync(cancellationToken))
        {
            var key = (
                reader.GetString(0),
                reader.GetString(1),
                reader.GetBoolean(2),
                reader.IsDBNull(3) ? null : reader.GetString(3));
            if (!groups.TryGetValue(key, out var columns))
            {
                columns = [];
                groups[key] = columns;
            }
            columns.Add(reader.GetString(4));
        }

        foreach (var pair in groups)
        {
            GetTable(tables, pair.Key.Table).Indexes.Add(
                new IndexFingerprint(pair.Key.Name, pair.Key.Unique, pair.Key.Filter, pair.Value));
        }
    }

    private static string StoreType(string type, short maxLength, byte precision, byte scale) =>
        type.ToLowerInvariant() switch
        {
            "nvarchar" or "nchar" => $"{type}({(maxLength == -1 ? "max" : maxLength / 2)})",
            "varchar" or "char" or "varbinary" or "binary" =>
                $"{type}({(maxLength == -1 ? "max" : maxLength)})",
            "decimal" or "numeric" => $"{type}({precision},{scale})",
            "datetime2" or "datetimeoffset" or "time" when scale != 7 => $"{type}({scale})",
            _ => type
        };

    private static MutableTable GetTable(IDictionary<string, MutableTable> tables, string name)
    {
        if (!tables.TryGetValue(name, out var table))
        {
            table = new MutableTable(name);
            tables[name] = table;
        }
        return table;
    }

    private static DbCommand Command(DbConnection connection, DbTransaction? transaction, string sql)
    {
        var command = connection.CreateCommand();
        command.Transaction = transaction;
        command.CommandText = sql;
        return command;
    }

    private static void Parameter(DbCommand command, string name, object value)
    {
        var parameter = command.CreateParameter();
        parameter.ParameterName = name;
        parameter.Value = value;
        command.Parameters.Add(parameter);
    }

    private sealed class MutableTable(string name)
    {
        public List<ColumnFingerprint> Columns { get; } = [];
        public List<KeyFingerprint> Keys { get; } = [];
        public List<ForeignKeyFingerprint> ForeignKeys { get; } = [];
        public List<IndexFingerprint> Indexes { get; } = [];

        public TableFingerprint Build() => new(
            name,
            Columns.OrderBy(item => item.Name, StringComparer.OrdinalIgnoreCase).ToArray(),
            Keys.OrderBy(item => item.Name, StringComparer.OrdinalIgnoreCase).ToArray(),
            ForeignKeys.OrderBy(item => item.Name, StringComparer.OrdinalIgnoreCase).ToArray(),
            Indexes.OrderBy(item => item.Name, StringComparer.OrdinalIgnoreCase).ToArray());
    }
}
