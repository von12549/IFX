using System.Data;
using System.Data.Common;
using IFX.BuildingBlocks.EntityFrameworkCore.Migrations;

namespace IFX.Modules.Auth.Infrastructure.Persistence.Migrations.Legacy;

public sealed class SqlServerAuthLegacyAdopter
{
    private readonly TimeSpan _lockTimeout;

    public SqlServerAuthLegacyAdopter(TimeSpan? lockTimeout = null)
    {
        _lockTimeout = lockTimeout ?? TimeSpan.FromSeconds(60);
        if (_lockTimeout < TimeSpan.Zero || _lockTimeout.TotalMilliseconds > int.MaxValue)
        {
            throw new ArgumentOutOfRangeException(nameof(lockTimeout));
        }
    }

    public async Task<AuthLegacyAdoptionPlan> RunAsync(
        DbConnection connection,
        IReadOnlyCollection<string> currentMigrationIds,
        IReadOnlyCollection<string> knownForeignMigrationIds,
        string canonicalProductVersion,
        Func<DbConnection, DbTransaction?, CancellationToken, Task<SchemaFingerprintVerification>> verifyFingerprint,
        bool explicitAdoption,
        bool dryRun,
        bool acquireLock = true,
        CancellationToken cancellationToken = default)
    {
        ArgumentNullException.ThrowIfNull(connection);
        ArgumentNullException.ThrowIfNull(currentMigrationIds);
        ArgumentNullException.ThrowIfNull(knownForeignMigrationIds);
        ArgumentNullException.ThrowIfNull(verifyFingerprint);

        var openedHere = connection.State != ConnectionState.Open;
        if (openedHere)
        {
            await connection.OpenAsync(cancellationToken);
        }

        try
        {
            if (dryRun)
            {
                return await CreatePlanAsync(
                    connection,
                    null,
                    currentMigrationIds,
                    knownForeignMigrationIds,
                    canonicalProductVersion,
                    verifyFingerprint,
                    explicitAdoption,
                    cancellationToken);
            }

            await using var transaction = await connection.BeginTransactionAsync(cancellationToken);
            try
            {
                if (acquireLock)
                {
                    await AcquireLockAsync(connection, transaction, cancellationToken);
                }
                var before = await CreatePlanAsync(
                    connection,
                    transaction,
                    currentMigrationIds,
                    knownForeignMigrationIds,
                    canonicalProductVersion,
                    verifyFingerprint,
                    explicitAdoption,
                    cancellationToken);
                if (!before.CanApply)
                {
                    throw new HistoryBootstrapException(
                        $"Auth legacy adoption preflight failed: {string.Join(" ", before.Errors)}");
                }

                if (before.HasChanges)
                {
                    await EnsureTargetHistoryAsync(connection, transaction, cancellationToken);
                    foreach (var migrationId in before.TargetRowsToDelete)
                    {
                        await DeleteTargetRowAsync(connection, transaction, migrationId, cancellationToken);
                    }

                    if (before.CanonicalRowToInsert is not null)
                    {
                        await InsertCanonicalRowAsync(
                            connection,
                            transaction,
                            before.CanonicalRowToInsert,
                            cancellationToken);
                    }
                }

                var after = await CreatePlanAsync(
                    connection,
                    transaction,
                    currentMigrationIds,
                    knownForeignMigrationIds,
                    canonicalProductVersion,
                    verifyFingerprint,
                    explicitAdoption,
                    cancellationToken);
                if (!after.CanApply || after.Classification != AuthLegacyAdoptionClassification.AlreadyCanonical)
                {
                    throw new HistoryBootstrapException(
                        "Auth legacy adoption post-validation failed; no changes were committed.");
                }

                await transaction.CommitAsync(cancellationToken);
                return before;
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

    private static async Task<AuthLegacyAdoptionPlan> CreatePlanAsync(
        DbConnection connection,
        DbTransaction? transaction,
        IReadOnlyCollection<string> currentMigrationIds,
        IReadOnlyCollection<string> knownForeignMigrationIds,
        string canonicalProductVersion,
        Func<DbConnection, DbTransaction?, CancellationToken, Task<SchemaFingerprintVerification>> verifyFingerprint,
        bool explicitAdoption,
        CancellationToken cancellationToken)
    {
        var sourceRows = await ReadHistoryAsync(connection, transaction, "dbo", cancellationToken);
        var targetRows = await ReadHistoryAsync(connection, transaction, ModuleDatabase.Schema, cancellationToken);
        var fingerprint = await verifyFingerprint(connection, transaction, cancellationToken);
        return AuthLegacyAdoptionPlanner.Create(
            sourceRows,
            targetRows,
            currentMigrationIds,
            knownForeignMigrationIds,
            canonicalProductVersion,
            fingerprint.Matches,
            explicitAdoption);
    }

    private async Task AcquireLockAsync(
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
        await using var command = Command(connection, transaction, sql);
        Parameter(command, "@resource", SqlServerHistoryBootstrapper.LockResource);
        Parameter(command, "@timeout", checked((int)_lockTimeout.TotalMilliseconds));
        if (Convert.ToInt32(await command.ExecuteScalarAsync(cancellationToken)) < 0)
        {
            throw new HistoryBootstrapException("Could not acquire the database migration lock for Auth adoption.");
        }
    }

    private static async Task<IReadOnlyList<MigrationHistoryRow>> ReadHistoryAsync(
        DbConnection connection,
        DbTransaction? transaction,
        string schema,
        CancellationToken cancellationToken)
    {
        const string existsSql = """
            SELECT CASE WHEN EXISTS (
                SELECT 1 FROM sys.tables t
                JOIN sys.schemas s ON s.schema_id = t.schema_id
                WHERE s.name = @schema AND t.name = @table)
            THEN 1 ELSE 0 END;
            """;
        await using var exists = Command(connection, transaction, existsSql);
        Parameter(exists, "@schema", schema);
        Parameter(exists, "@table", ModuleDatabase.HistoryTable);
        if (Convert.ToInt32(await exists.ExecuteScalarAsync(cancellationToken)) == 0)
        {
            return [];
        }

        var sql = $"SELECT [MigrationId], [ProductVersion] FROM [{schema}].[{ModuleDatabase.HistoryTable}] ORDER BY [MigrationId];";
        await using var command = Command(connection, transaction, sql);
        await using var reader = await command.ExecuteReaderAsync(cancellationToken);
        var rows = new List<MigrationHistoryRow>();
        while (await reader.ReadAsync(cancellationToken))
        {
            rows.Add(new(reader.GetString(0), reader.GetString(1)));
        }

        return rows;
    }

    private static async Task EnsureTargetHistoryAsync(
        DbConnection connection,
        DbTransaction transaction,
        CancellationToken cancellationToken)
    {
        var sql = $"""
            IF SCHEMA_ID(N'{ModuleDatabase.Schema}') IS NULL
                EXEC(N'CREATE SCHEMA [{ModuleDatabase.Schema}]');
            IF OBJECT_ID(N'[{ModuleDatabase.Schema}].[{ModuleDatabase.HistoryTable}]', N'U') IS NULL
                CREATE TABLE [{ModuleDatabase.Schema}].[{ModuleDatabase.HistoryTable}] (
                    [MigrationId] nvarchar(150) NOT NULL PRIMARY KEY,
                    [ProductVersion] nvarchar(32) NOT NULL);
            """;
        await using var command = Command(connection, transaction, sql);
        await command.ExecuteNonQueryAsync(cancellationToken);
    }

    private static async Task DeleteTargetRowAsync(
        DbConnection connection,
        DbTransaction transaction,
        string migrationId,
        CancellationToken cancellationToken)
    {
        var sql = $"DELETE FROM [{ModuleDatabase.Schema}].[{ModuleDatabase.HistoryTable}] WHERE [MigrationId] = @id;";
        await using var command = Command(connection, transaction, sql);
        Parameter(command, "@id", migrationId);
        await command.ExecuteNonQueryAsync(cancellationToken);
    }

    private static async Task InsertCanonicalRowAsync(
        DbConnection connection,
        DbTransaction transaction,
        MigrationHistoryRow row,
        CancellationToken cancellationToken)
    {
        var sql = $"""
            IF NOT EXISTS (
                SELECT 1 FROM [{ModuleDatabase.Schema}].[{ModuleDatabase.HistoryTable}]
                WHERE [MigrationId] = @id)
            INSERT INTO [{ModuleDatabase.Schema}].[{ModuleDatabase.HistoryTable}]
                ([MigrationId], [ProductVersion]) VALUES (@id, @version);
            """;
        await using var command = Command(connection, transaction, sql);
        Parameter(command, "@id", row.MigrationId);
        Parameter(command, "@version", row.ProductVersion);
        await command.ExecuteNonQueryAsync(cancellationToken);
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
}
