using System.Data;
using System.Data.Common;

namespace IFX.BuildingBlocks.EntityFrameworkCore.Migrations;

public sealed class SqlServerHistoryBootstrapper
{
    public const string LockResource = "IFX.DatabaseMigration";
    public const string HistoryTable = "__EFMigrationsHistory";

    private readonly TimeSpan _lockTimeout;

    public SqlServerHistoryBootstrapper(TimeSpan? lockTimeout = null)
    {
        _lockTimeout = lockTimeout ?? TimeSpan.FromSeconds(60);
        if (_lockTimeout < TimeSpan.Zero || _lockTimeout.TotalMilliseconds > int.MaxValue)
        {
            throw new ArgumentOutOfRangeException(nameof(lockTimeout));
        }
    }

    public async Task<HistoryBootstrapResult> RunAsync(
        DbConnection connection,
        IReadOnlyList<ModuleMigrationCatalog> catalogs,
        bool dryRun,
        bool acquireLock = true,
        CancellationToken cancellationToken = default)
    {
        ArgumentNullException.ThrowIfNull(connection);
        ArgumentNullException.ThrowIfNull(catalogs);

        var openedHere = connection.State != ConnectionState.Open;
        if (openedHere)
        {
            await connection.OpenAsync(cancellationToken);
        }

        try
        {
            if (dryRun)
            {
                var snapshot = await ReadSnapshotAsync(connection, null, catalogs, cancellationToken);
                return new HistoryBootstrapResult(true, HistoryBootstrapPlanner.Create(catalogs, snapshot), null);
            }

            await using var transaction = await connection.BeginTransactionAsync(cancellationToken);
            try
            {
                if (acquireLock)
                {
                    await AcquireApplicationLockAsync(connection, transaction, cancellationToken);
                }

                var beforeSnapshot = await ReadSnapshotAsync(connection, transaction, catalogs, cancellationToken);
                var before = HistoryBootstrapPlanner.Create(catalogs, beforeSnapshot);
                if (!before.CanApply)
                {
                    throw new HistoryBootstrapException(
                        $"History bootstrap preflight failed: {string.Join(" ", before.Errors)}");
                }

                foreach (var module in before.Modules.Where(module =>
                             module.CreateHistoryTable || module.RowsToInsert.Count > 0))
                {
                    await EnsureHistoryTableAsync(connection, transaction, module.Schema, cancellationToken);
                    foreach (var row in module.RowsToInsert)
                    {
                        await InsertHistoryRowAsync(
                            connection,
                            transaction,
                            module.Schema,
                            row,
                            cancellationToken);
                    }
                }

                var afterSnapshot = await ReadSnapshotAsync(connection, transaction, catalogs, cancellationToken);
                var after = HistoryBootstrapPlanner.Create(catalogs, afterSnapshot);
                if (!after.CanApply || after.HasChanges)
                {
                    throw new HistoryBootstrapException(
                        "History bootstrap post-validation failed; no changes were committed.");
                }

                await transaction.CommitAsync(cancellationToken);
                return new HistoryBootstrapResult(false, before, after);
            }
            catch
            {
                await transaction.RollbackAsync(CancellationToken.None);
                throw;
            }
        }
        finally
        {
            if (openedHere)
            {
                await connection.CloseAsync();
            }
        }
    }

    public async Task<HistoryBootstrapSnapshot> ReadSnapshotAsync(
        DbConnection connection,
        DbTransaction? transaction,
        IReadOnlyList<ModuleMigrationCatalog> catalogs,
        CancellationToken cancellationToken = default)
    {
        ArgumentNullException.ThrowIfNull(connection);
        ArgumentNullException.ThrowIfNull(catalogs);

        var sharedExists = await HistoryTableExistsAsync(
            connection,
            transaction,
            "dbo",
            cancellationToken);
        var sharedRows = sharedExists
            ? await ReadHistoryRowsAsync(connection, transaction, "dbo", cancellationToken)
            : [];

        var histories = new Dictionary<string, ModuleHistoryState>(StringComparer.OrdinalIgnoreCase);
        var schemas = new Dictionary<string, ModuleSchemaState>(StringComparer.OrdinalIgnoreCase);
        foreach (var catalog in catalogs)
        {
            ValidateIdentifier(catalog.Schema, "schema");
            foreach (var table in catalog.RequiredTables)
            {
                ValidateIdentifier(table, "table");
            }

            var historyExists = await HistoryTableExistsAsync(
                connection,
                transaction,
                catalog.Schema,
                cancellationToken);
            var rows = historyExists
                ? await ReadHistoryRowsAsync(connection, transaction, catalog.Schema, cancellationToken)
                : [];
            histories[catalog.Module] = new ModuleHistoryState(historyExists, rows);
            schemas[catalog.Module] = await ReadSchemaStateAsync(
                connection,
                transaction,
                catalog,
                cancellationToken);
        }

        return new HistoryBootstrapSnapshot(sharedExists, sharedRows, histories, schemas);
    }

    private async Task AcquireApplicationLockAsync(
        DbConnection connection,
        DbTransaction transaction,
        CancellationToken cancellationToken)
    {
        const string sql = """
            DECLARE @result int;
            EXEC @result = sys.sp_getapplock
                @Resource = @resource,
                @LockMode = N'Exclusive',
                @LockOwner = N'Transaction',
                @LockTimeout = @timeout;
            SELECT @result;
            """;
        await using var command = CreateCommand(connection, transaction, sql);
        AddParameter(command, "@resource", LockResource);
        AddParameter(command, "@timeout", checked((int)_lockTimeout.TotalMilliseconds));
        var result = Convert.ToInt32(await command.ExecuteScalarAsync(cancellationToken));
        if (result < 0)
        {
            throw new HistoryBootstrapException(
                $"Could not acquire the database migration lock within {_lockTimeout.TotalSeconds:0.###} seconds.");
        }
    }

    private static async Task EnsureHistoryTableAsync(
        DbConnection connection,
        DbTransaction transaction,
        string schema,
        CancellationToken cancellationToken)
    {
        ValidateIdentifier(schema, "schema");
        var quotedSchema = Quote(schema);
        var qualifiedHistory = $"{quotedSchema}.{Quote(HistoryTable)}";
        var sql = $"""
            IF SCHEMA_ID(N'{schema}') IS NULL
                EXEC(N'CREATE SCHEMA {quotedSchema}');

            IF OBJECT_ID(N'{qualifiedHistory}', N'U') IS NULL
            BEGIN
                CREATE TABLE {qualifiedHistory} (
                    [MigrationId] nvarchar(150) NOT NULL,
                    [ProductVersion] nvarchar(32) NOT NULL,
                    CONSTRAINT {Quote($"PK_{schema}_{HistoryTable}")} PRIMARY KEY ([MigrationId])
                );
            END;
            """;
        await using var command = CreateCommand(connection, transaction, sql);
        await command.ExecuteNonQueryAsync(cancellationToken);
    }

    private static async Task InsertHistoryRowAsync(
        DbConnection connection,
        DbTransaction transaction,
        string schema,
        MigrationHistoryRow row,
        CancellationToken cancellationToken)
    {
        ValidateIdentifier(schema, "schema");
        var qualifiedHistory = $"{Quote(schema)}.{Quote(HistoryTable)}";
        var sql = $"""
            IF NOT EXISTS (SELECT 1 FROM {qualifiedHistory} WHERE [MigrationId] = @migrationId)
                INSERT INTO {qualifiedHistory} ([MigrationId], [ProductVersion])
                VALUES (@migrationId, @productVersion);
            """;
        await using var command = CreateCommand(connection, transaction, sql);
        AddParameter(command, "@migrationId", row.MigrationId);
        AddParameter(command, "@productVersion", row.ProductVersion);
        await command.ExecuteNonQueryAsync(cancellationToken);
    }

    private static async Task<bool> HistoryTableExistsAsync(
        DbConnection connection,
        DbTransaction? transaction,
        string schema,
        CancellationToken cancellationToken)
    {
        ValidateIdentifier(schema, "schema");
        const string sql = """
            SELECT CASE WHEN EXISTS (
                SELECT 1
                FROM sys.tables AS t
                INNER JOIN sys.schemas AS s ON s.schema_id = t.schema_id
                WHERE s.name = @schema AND t.name = @table)
            THEN 1 ELSE 0 END;
            """;
        await using var command = CreateCommand(connection, transaction, sql);
        AddParameter(command, "@schema", schema);
        AddParameter(command, "@table", HistoryTable);
        return Convert.ToInt32(await command.ExecuteScalarAsync(cancellationToken)) == 1;
    }

    private static async Task<IReadOnlyList<MigrationHistoryRow>> ReadHistoryRowsAsync(
        DbConnection connection,
        DbTransaction? transaction,
        string schema,
        CancellationToken cancellationToken)
    {
        ValidateIdentifier(schema, "schema");
        var sql = $"""
            SELECT [MigrationId], [ProductVersion]
            FROM {Quote(schema)}.{Quote(HistoryTable)}
            ORDER BY [MigrationId];
            """;
        await using var command = CreateCommand(connection, transaction, sql);
        await using var reader = await command.ExecuteReaderAsync(cancellationToken);
        var rows = new List<MigrationHistoryRow>();
        while (await reader.ReadAsync(cancellationToken))
        {
            rows.Add(new MigrationHistoryRow(reader.GetString(0), reader.GetString(1)));
        }

        return rows;
    }

    private static async Task<ModuleSchemaState> ReadSchemaStateAsync(
        DbConnection connection,
        DbTransaction? transaction,
        ModuleMigrationCatalog catalog,
        CancellationToken cancellationToken)
    {
        if (catalog.RequiredTables.Count == 0)
        {
            return ModuleSchemaState.Absent;
        }

        var parameterNames = catalog.RequiredTables
            .Select((_, index) => $"@table{index}")
            .ToArray();
        var sql = $"""
            SELECT COUNT(DISTINCT t.name)
            FROM sys.tables AS t
            INNER JOIN sys.schemas AS s ON s.schema_id = t.schema_id
            WHERE s.name = @schema AND t.name IN ({string.Join(", ", parameterNames)});
            """;
        await using var command = CreateCommand(connection, transaction, sql);
        AddParameter(command, "@schema", catalog.Schema);
        for (var index = 0; index < catalog.RequiredTables.Count; index++)
        {
            AddParameter(command, parameterNames[index], catalog.RequiredTables[index]);
        }

        var count = Convert.ToInt32(await command.ExecuteScalarAsync(cancellationToken));
        return count switch
        {
            0 => ModuleSchemaState.Absent,
            _ when count == catalog.RequiredTables.Count => ModuleSchemaState.Complete,
            _ => ModuleSchemaState.Partial
        };
    }

    private static DbCommand CreateCommand(
        DbConnection connection,
        DbTransaction? transaction,
        string commandText)
    {
        var command = connection.CreateCommand();
        command.CommandText = commandText;
        command.Transaction = transaction;
        return command;
    }

    private static void AddParameter(DbCommand command, string name, object value)
    {
        var parameter = command.CreateParameter();
        parameter.ParameterName = name;
        parameter.Value = value;
        command.Parameters.Add(parameter);
    }

    private static string Quote(string identifier)
    {
        ValidateIdentifier(identifier, "SQL");
        return $"[{identifier}]";
    }

    private static void ValidateIdentifier(string identifier, string kind)
    {
        if (string.IsNullOrWhiteSpace(identifier) ||
            !identifier.All(character => char.IsAsciiLetterOrDigit(character) || character == '_') ||
            !char.IsAsciiLetter(identifier[0]))
        {
            throw new HistoryBootstrapException($"Invalid {kind} identifier in migration catalog.");
        }
    }
}
