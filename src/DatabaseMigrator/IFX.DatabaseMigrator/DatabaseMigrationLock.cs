using Microsoft.Data.SqlClient;

namespace IFX.DatabaseMigrator;

public sealed class DatabaseMigrationLock : IAsyncDisposable
{
    private readonly SqlConnection _connection;
    private bool _held;

    private DatabaseMigrationLock(SqlConnection connection)
    {
        _connection = connection;
    }

    public SqlConnection Connection => _connection;

    public static async Task<DatabaseMigrationLock> AcquireAsync(
        string connectionString,
        TimeSpan timeout,
        CancellationToken cancellationToken)
    {
        var connection = new SqlConnection(connectionString);
        await connection.OpenAsync(cancellationToken);
        var migrationLock = new DatabaseMigrationLock(connection);
        try
        {
            await using var command = connection.CreateCommand();
            command.CommandText = """
                DECLARE @result int;
                EXEC @result = sys.sp_getapplock
                    @Resource = N'IFX.DatabaseMigration',
                    @LockMode = N'Exclusive',
                    @LockOwner = N'Session',
                    @LockTimeout = @timeout;
                SELECT @result;
                """;
            command.Parameters.AddWithValue("@timeout", checked((int)timeout.TotalMilliseconds));
            var result = Convert.ToInt32(await command.ExecuteScalarAsync(cancellationToken));
            if (result < 0)
            {
                throw new InvalidOperationException(
                    $"Could not acquire the database migration lock within {timeout.TotalSeconds:0.###} seconds.");
            }
            migrationLock._held = true;
            return migrationLock;
        }
        catch
        {
            await connection.DisposeAsync();
            throw;
        }
    }

    public async ValueTask DisposeAsync()
    {
        if (_held)
        {
            await using var command = _connection.CreateCommand();
            command.CommandText = "EXEC sys.sp_releaseapplock @Resource = N'IFX.DatabaseMigration', @LockOwner = N'Session';";
            await command.ExecuteNonQueryAsync();
            _held = false;
        }
        await _connection.DisposeAsync();
    }
}
