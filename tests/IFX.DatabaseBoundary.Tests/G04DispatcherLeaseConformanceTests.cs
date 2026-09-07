using FluentAssertions;
using Microsoft.Data.SqlClient;
using Xunit;

namespace IFX.DatabaseBoundary.Tests;

[Collection(SqlServerMigrationCollection.Name)]
public sealed class G04DispatcherLeaseConformanceTests(SqlServerMigrationFixture fixture)
{
    [Fact]
    public async Task Two_claimants_atomically_claim_disjoint_bounded_batches()
    {
        var connectionString = await CreateFixtureAsync("concurrent", 8);
        var now = DateTimeOffset.UtcNow;

        var claims = await Task.WhenAll(
            ClaimAsync(connectionString, "worker-a", now, 4),
            ClaimAsync(connectionString, "worker-b", now, 4));

        claims.SelectMany(x => x).Should().HaveCount(8).And.OnlyHaveUniqueItems(x => x.EventId);
        claims.Should().OnlyContain(batch => batch.Count <= 4);
    }

    [Fact]
    public async Task Expired_lease_is_reclaimed_with_same_event_identity()
    {
        var connectionString = await CreateFixtureAsync("expiry", 1);
        var now = DateTimeOffset.UtcNow;
        var first = (await ClaimAsync(connectionString, "worker-a", now, 1)).Single();

        (await ClaimAsync(connectionString, "worker-b", now.AddSeconds(10), 1)).Should().BeEmpty();
        var reclaimed = (await ClaimAsync(connectionString, "worker-b", now.AddMinutes(2), 1)).Single();

        reclaimed.EventId.Should().Be(first.EventId);
        reclaimed.LeaseOwner.Should().Be("worker-b");
    }

    [Fact]
    public async Task Completion_is_conditional_on_owner_and_concurrency_token()
    {
        var connectionString = await CreateFixtureAsync("completion", 1);
        var lease = (await ClaimAsync(connectionString, "worker-a", DateTimeOffset.UtcNow, 1)).Single();

        (await CompleteAsync(connectionString, lease with { LeaseOwner = "stale-worker" })).Should().BeFalse();
        (await CompleteAsync(connectionString, lease)).Should().BeTrue();
        (await CompleteAsync(connectionString, lease)).Should().BeFalse();
    }

    [Fact]
    public async Task Renewal_changes_token_and_prevents_stale_completion()
    {
        var connectionString = await CreateFixtureAsync("renewal", 1);
        var lease = (await ClaimAsync(connectionString, "worker-a", DateTimeOffset.UtcNow, 1)).Single();
        var renewed = await RenewAsync(connectionString, lease, DateTimeOffset.UtcNow.AddMinutes(3));

        renewed.Should().NotBeNull();
        renewed!.ConcurrencyToken.Should().NotEqual(lease.ConcurrencyToken);
        (await CompleteAsync(connectionString, lease)).Should().BeFalse();
        (await CompleteAsync(connectionString, renewed)).Should().BeTrue();
    }

    [Fact]
    public async Task Earlier_sequence_blocks_later_partition_item_but_other_partition_progresses()
    {
        var connectionString = await CreateFixtureAsync("partition", 0);
        await InsertAsync(connectionString, "crm", "tenant-a", 1);
        await InsertAsync(connectionString, "crm", "tenant-a", 2);
        await InsertAsync(connectionString, "crm", "tenant-b", 1);

        var claimed = await ClaimAsync(connectionString, "worker-a", DateTimeOffset.UtcNow, 3);

        claimed.Should().HaveCount(2);
        claimed.Select(x => (x.PartitionKey, x.Sequence)).Should().BeEquivalentTo(new[] { ("tenant-a", 1L), ("tenant-b", 1L) });
    }

    [Fact]
    public async Task Crash_injection_preserves_truth_before_and_after_send_acknowledgement()
    {
        var connectionString = await CreateFixtureAsync("crash", 2);
        var now = DateTimeOffset.UtcNow;
        var claimed = await ClaimAsync(connectionString, "worker-a", now, 2);

        // Crash before send: no completion is written, so the original EventId is reclaimable.
        // Crash after send but before acknowledgement is indistinguishable and may redeliver at-least-once.
        var reclaimed = await ClaimAsync(connectionString, "worker-b", now.AddMinutes(2), 2);
        reclaimed.Select(item => item.EventId).Should().BeEquivalentTo(claimed.Select(item => item.EventId));

        // Once the broker acknowledgement has been conditionally persisted, a later crash cannot reclaim it.
        (await CompleteAsync(connectionString, reclaimed[0])).Should().BeTrue();
        var afterCompletion = await ClaimAsync(connectionString, "worker-c", now.AddMinutes(4), 2);
        afterCompletion.Should().NotContain(item => item.EventId == reclaimed[0].EventId);
    }

    private async Task<string> CreateFixtureAsync(string scenario, int rows)
    {
        var connectionString = await fixture.CreateDatabaseAsync($"g04_{scenario}");
        await ExecuteAsync(connectionString, "CREATE SCHEMA [g04];");
        await ExecuteAsync(connectionString, """
            CREATE TABLE [g04].[ReferenceOutbox] (
                [EventId] uniqueidentifier NOT NULL PRIMARY KEY,
                [ModuleId] nvarchar(40) NOT NULL,
                [PartitionKey] nvarchar(100) NOT NULL,
                [Sequence] bigint NOT NULL,
                [State] nvarchar(20) NOT NULL,
                [LeaseOwner] nvarchar(128) NULL,
                [LeaseUntil] datetimeoffset NULL,
                [ConcurrencyToken] rowversion NOT NULL);
            """);
        for (var index = 1; index <= rows; index++) await InsertAsync(connectionString, index % 2 == 0 ? "crm" : "transaction", $"tenant-{index}", index);
        return connectionString;
    }

    private static async Task InsertAsync(string connectionString, string moduleId, string partitionKey, long sequence)
    {
        await using var connection = new SqlConnection(connectionString);
        await connection.OpenAsync();
        await using var command = connection.CreateCommand();
        command.CommandText = "INSERT INTO [g04].[ReferenceOutbox] ([EventId],[ModuleId],[PartitionKey],[Sequence],[State]) VALUES (@id,@module,@partition,@sequence,N'Pending');";
        command.Parameters.AddWithValue("@id", Guid.NewGuid());
        command.Parameters.AddWithValue("@module", moduleId);
        command.Parameters.AddWithValue("@partition", partitionKey);
        command.Parameters.AddWithValue("@sequence", sequence);
        await command.ExecuteNonQueryAsync();
    }

    private static async Task<IReadOnlyList<LeaseRow>> ClaimAsync(string connectionString, string owner, DateTimeOffset now, int batchSize)
    {
        await using var connection = new SqlConnection(connectionString);
        await connection.OpenAsync();
        await using var transaction = await connection.BeginTransactionAsync();
        await using var command = connection.CreateCommand();
        command.Transaction = (SqlTransaction)transaction;
        command.CommandText = """
            ;WITH eligible AS (
                SELECT TOP (@batch) current_row.*
                FROM [g04].[ReferenceOutbox] current_row WITH (UPDLOCK, READPAST, ROWLOCK)
                WHERE current_row.[State] = N'Pending'
                  AND (current_row.[LeaseUntil] IS NULL OR current_row.[LeaseUntil] <= @now)
                  AND NOT EXISTS (
                      SELECT 1 FROM [g04].[ReferenceOutbox] earlier
                      WHERE earlier.[ModuleId] = current_row.[ModuleId]
                        AND earlier.[PartitionKey] = current_row.[PartitionKey]
                        AND earlier.[Sequence] < current_row.[Sequence]
                        AND earlier.[State] <> N'Delivered')
                ORDER BY current_row.[ModuleId], current_row.[Sequence], current_row.[EventId])
            UPDATE eligible SET [LeaseOwner] = @owner, [LeaseUntil] = DATEADD(minute, 1, @now)
            OUTPUT inserted.[EventId], inserted.[ModuleId], inserted.[PartitionKey], inserted.[Sequence], inserted.[LeaseOwner], inserted.[LeaseUntil], inserted.[ConcurrencyToken];
            """;
        command.Parameters.AddWithValue("@batch", batchSize);
        command.Parameters.AddWithValue("@now", now);
        command.Parameters.AddWithValue("@owner", owner);
        var rows = new List<LeaseRow>();
        await using (var reader = await command.ExecuteReaderAsync())
        {
            while (await reader.ReadAsync()) rows.Add(new LeaseRow(reader.GetGuid(0), reader.GetString(1), reader.GetString(2), reader.GetInt64(3), reader.GetString(4), reader.GetDateTimeOffset(5), (byte[])reader[6]));
        }
        await transaction.CommitAsync();
        return rows;
    }

    private static async Task<LeaseRow?> RenewAsync(string connectionString, LeaseRow lease, DateTimeOffset until)
    {
        await using var connection = new SqlConnection(connectionString);
        await connection.OpenAsync();
        await using var command = connection.CreateCommand();
        command.CommandText = "UPDATE [g04].[ReferenceOutbox] SET [LeaseUntil]=@until OUTPUT inserted.[EventId],inserted.[ModuleId],inserted.[PartitionKey],inserted.[Sequence],inserted.[LeaseOwner],inserted.[LeaseUntil],inserted.[ConcurrencyToken] WHERE [EventId]=@id AND [LeaseOwner]=@owner AND [ConcurrencyToken]=@token AND [State]=N'Pending';";
        command.Parameters.AddWithValue("@until", until); command.Parameters.AddWithValue("@id", lease.EventId); command.Parameters.AddWithValue("@owner", lease.LeaseOwner); command.Parameters.AddWithValue("@token", lease.ConcurrencyToken);
        await using var reader = await command.ExecuteReaderAsync();
        return await reader.ReadAsync() ? new LeaseRow(reader.GetGuid(0), reader.GetString(1), reader.GetString(2), reader.GetInt64(3), reader.GetString(4), reader.GetDateTimeOffset(5), (byte[])reader[6]) : null;
    }

    private static async Task<bool> CompleteAsync(string connectionString, LeaseRow lease)
    {
        await using var connection = new SqlConnection(connectionString);
        await connection.OpenAsync();
        await using var command = connection.CreateCommand();
        command.CommandText = "UPDATE [g04].[ReferenceOutbox] SET [State]=N'Delivered',[LeaseOwner]=NULL,[LeaseUntil]=NULL WHERE [EventId]=@id AND [LeaseOwner]=@owner AND [ConcurrencyToken]=@token AND [State]=N'Pending';";
        command.Parameters.AddWithValue("@id", lease.EventId); command.Parameters.AddWithValue("@owner", lease.LeaseOwner); command.Parameters.AddWithValue("@token", lease.ConcurrencyToken);
        return await command.ExecuteNonQueryAsync() == 1;
    }

    private static async Task ExecuteAsync(string connectionString, string sql)
    {
        await using var connection = new SqlConnection(connectionString);
        await connection.OpenAsync();
        await using var command = connection.CreateCommand(); command.CommandText = sql; await command.ExecuteNonQueryAsync();
    }

    private sealed record LeaseRow(Guid EventId, string ModuleId, string PartitionKey, long Sequence, string LeaseOwner, DateTimeOffset LeaseUntil, byte[] ConcurrencyToken);
}
