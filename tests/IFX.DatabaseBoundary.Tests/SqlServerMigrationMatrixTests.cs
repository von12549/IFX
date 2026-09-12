using FluentAssertions;
using IFX.BuildingBlocks.EntityFrameworkCore.Migrations;
using IFX.DatabaseMigrator;
using IFX.Modules.IAM.Infrastructure.Persistence.Migrations.Legacy;
using Microsoft.Data.SqlClient;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Migrations;
using Testcontainers.MsSql;
using Xunit;

namespace IFX.DatabaseBoundary.Tests;

[CollectionDefinition(Name, DisableParallelization = true)]
public sealed class SqlServerMigrationCollection : ICollectionFixture<SqlServerMigrationFixture>
{
    public const string Name = "G02 SQL Server migration matrix";
}

public sealed class SqlServerMigrationFixture : IAsyncLifetime
{
    private readonly MsSqlContainer _container = new MsSqlBuilder()
        .WithImage("mcr.microsoft.com/mssql/server:2022-latest")
        .WithPassword("G02_Strong!Password_2026")
        .Build();

    public Task InitializeAsync() => _container.StartAsync();

    public Task DisposeAsync() => _container.DisposeAsync().AsTask();

    public async Task<string> CreateDatabaseAsync(string scenario)
    {
        var database = $"G02_{scenario}_{Guid.NewGuid():N}";
        await using var connection = new SqlConnection(_container.GetConnectionString());
        await connection.OpenAsync();
        await using var command = connection.CreateCommand();
        command.CommandText = $"CREATE DATABASE [{database}];";
        await command.ExecuteNonQueryAsync();
        return new SqlConnectionStringBuilder(_container.GetConnectionString())
        {
            InitialCatalog = database
        }.ConnectionString;
    }

    public string MasterConnectionString => _container.GetConnectionString();
}

[Collection(SqlServerMigrationCollection.Name)]
public sealed class SqlServerMigrationMatrixTests(SqlServerMigrationFixture fixture)
{
    [Fact]
    public async Task Empty_database_migrates_to_latest_with_owned_metadata_and_is_idempotent()
    {
        var connectionString = await fixture.CreateDatabaseAsync("fresh");

        var first = await RunMigratorAsync(connectionString);
        var second = await RunMigratorAsync(connectionString);

        AssertSucceeded(first);
        first.Modules.Select(module => module.Module).Should().Equal(ExpectedModules);
        first.Modules.Sum(module => module.AppliedIds.Count).Should().Be(19);
        AssertSucceeded(second);
        second.Modules.Should().OnlyContain(module => module.AppliedIds.Count == 0);
        (await ScalarAsync<int>(connectionString, """
            SELECT COUNT(*) FROM sys.schemas WHERE name IN (N'auth', N'crm', N'registry', N'holdings', N'transaction');
            """)).Should().Be(5);
        (await ScalarAsync<int>(connectionString, """
            SELECT COUNT(*)
            FROM sys.foreign_keys fk
            JOIN sys.tables parent_table ON parent_table.object_id = fk.parent_object_id
            JOIN sys.schemas parent_schema ON parent_schema.schema_id = parent_table.schema_id
            JOIN sys.tables referenced_table ON referenced_table.object_id = fk.referenced_object_id
            JOIN sys.schemas referenced_schema ON referenced_schema.schema_id = referenced_table.schema_id
            WHERE parent_schema.name <> referenced_schema.name;
            """)).Should().Be(0);
        await G02SqlServerAssertions.AssertNoCrossSchemaForeignKeysAsync(connectionString);
        await AssertCurrentHistoriesAsync(connectionString);
    }

    [Fact]
    public async Task Shared_dbo_history_is_copied_exactly_and_retained_read_only()
    {
        var connectionString = await fixture.CreateDatabaseAsync("shared_history");
        AssertSucceeded(await RunMigratorAsync(connectionString));
        await ExecuteAsync(connectionString, """
            CREATE TABLE [dbo].[__EFMigrationsHistory] (
                [MigrationId] nvarchar(150) NOT NULL PRIMARY KEY,
                [ProductVersion] nvarchar(32) NOT NULL);
            INSERT INTO [dbo].[__EFMigrationsHistory]
            SELECT [MigrationId], [ProductVersion] FROM [auth].[__EFMigrationsHistory]
            UNION ALL SELECT [MigrationId], [ProductVersion] FROM [crm].[__EFMigrationsHistory]
            UNION ALL SELECT [MigrationId], [ProductVersion] FROM [registry].[__EFMigrationsHistory]
            UNION ALL SELECT [MigrationId], [ProductVersion] FROM [holdings].[__EFMigrationsHistory]
            UNION ALL SELECT [MigrationId], [ProductVersion] FROM [transaction].[__EFMigrationsHistory];
            DROP TABLE [auth].[__EFMigrationsHistory];
            DROP TABLE [crm].[__EFMigrationsHistory];
            DROP TABLE [registry].[__EFMigrationsHistory];
            DROP TABLE [holdings].[__EFMigrationsHistory];
            DROP TABLE [transaction].[__EFMigrationsHistory];
            """);
        var sharedBefore = await QueryStringsAsync(
            connectionString,
            "SELECT CONCAT([MigrationId], N'|', [ProductVersion]) FROM [dbo].[__EFMigrationsHistory] ORDER BY [MigrationId];");

        var result = await RunMigratorAsync(connectionString);

        AssertSucceeded(result);
        result.HistoryBootstrap!.Classification.ToString().Should().Be("CurrentSharedHistory");
        (await ScalarAsync<int>(connectionString, "SELECT COUNT(*) FROM [dbo].[__EFMigrationsHistory];"))
            .Should().Be(19);
        (await QueryStringsAsync(
                connectionString,
                "SELECT CONCAT([MigrationId], N'|', [ProductVersion]) FROM [dbo].[__EFMigrationsHistory] ORDER BY [MigrationId];"))
            .Should().Equal(sharedBefore);
        await AssertCurrentHistoriesAsync(connectionString);
    }

    [Theory]
    [InlineData("canonical")]
    [InlineData("pre-squash")]
    [InlineData("incorrect-alias")]
    public async Task Known_Auth_history_states_normalize_to_canonical_and_latest(string state)
    {
        var connectionString = await fixture.CreateDatabaseAsync($"auth_{state.Replace('-', '_')}");
        await using (var auth = ModuleRuntime.All.Single(runtime => runtime.ModuleName == "Auth").CreateContext(connectionString))
        {
            await auth.GetService<IMigrator>().MigrateAsync(AuthLegacyMigrationManifest.CanonicalInitialCreateId);
            await auth.Database.OpenConnectionAsync();
            var fingerprint = await new AuthSchemaFingerprintVerifier(
                    (IFX.Modules.IAM.Infrastructure.Persistence.IfxDbContext)auth)
                .VerifyAsync(auth.Database.GetDbConnection(), null);
            fingerprint.Matches.Should().BeTrue(
                "canonical Auth baseline differences: {0}",
                string.Join(" | ", fingerprint.Differences));
        }
        if (state == "pre-squash")
        {
            await ExecuteAsync(connectionString, """
                DROP TABLE [auth].[__EFMigrationsHistory];
                CREATE TABLE [dbo].[__EFMigrationsHistory] (
                    [MigrationId] nvarchar(150) NOT NULL PRIMARY KEY,
                    [ProductVersion] nvarchar(32) NOT NULL);
                """);
            foreach (var id in AuthLegacyMigrationManifest.PreSquashMigrationIds)
            {
                await InsertHistoryAsync(connectionString, "dbo", id, "8.0.11");
            }
        }
        else if (state == "incorrect-alias")
        {
            await ExecuteAsync(connectionString, $"""
                UPDATE [auth].[__EFMigrationsHistory]
                SET [MigrationId] = N'{AuthLegacyMigrationManifest.IncorrectSquashAlias}'
                WHERE [MigrationId] = N'{AuthLegacyMigrationManifest.CanonicalInitialCreateId}';
                """);
        }

        var result = await RunMigratorAsync(connectionString);

        AssertSucceeded(result);
        await AssertCurrentHistoriesAsync(connectionString);
        (await ScalarAsync<int>(connectionString, $"""
            SELECT COUNT(*) FROM [auth].[__EFMigrationsHistory]
            WHERE [MigrationId] = N'{AuthLegacyMigrationManifest.IncorrectSquashAlias}';
            """)).Should().Be(0);
    }

    [Fact]
    public async Task Partial_or_fingerprint_mismatched_Auth_schema_fails_without_stamping_history()
    {
        var partial = await fixture.CreateDatabaseAsync("auth_partial");
        await ExecuteAsync(partial, "CREATE SCHEMA [auth];");
        await ExecuteAsync(partial, "CREATE TABLE [auth].[Users] ([Id] uniqueidentifier NOT NULL PRIMARY KEY);");

        var partialResult = await RunMigratorAsync(partial, MigratorMode.Preflight, explicitAuthAdoption: true);

        partialResult.Result.Should().Be("failed");
        (await HistoryExistsAsync(partial, "auth")).Should().BeFalse();

        var mismatch = await fixture.CreateDatabaseAsync("auth_fingerprint");
        var authRuntime = ModuleRuntime.All.Single(runtime => runtime.ModuleName == "Auth");
        await using (var auth = authRuntime.CreateContext(mismatch))
        {
            await auth.GetService<IMigrator>().MigrateAsync(AuthLegacyMigrationManifest.CanonicalInitialCreateId);
            var fingerprint = AuthBaselineSchemaFingerprint.Create((IFX.Modules.IAM.Infrastructure.Persistence.IfxDbContext)auth);
            var table = fingerprint.Tables.First(item => item.Indexes.Count > 0);
            var index = table.Indexes[0];
            await ExecuteAsync(mismatch, $"DROP INDEX [{index.Name}] ON [auth].[{table.Name}]; DROP TABLE [auth].[__EFMigrationsHistory];");
        }

        var mismatchResult = await RunMigratorAsync(mismatch, MigratorMode.Apply, explicitAuthAdoption: true);

        mismatchResult.Result.Should().Be("failed");
        mismatchResult.Errors.Should().Contain(error => error.Contains("fingerprint", StringComparison.OrdinalIgnoreCase));
        (await HistoryExistsAsync(mismatch, "auth")).Should().BeFalse();
    }

    [Fact]
    public async Task Complete_historyless_Auth_schema_is_only_adopted_when_explicitly_authorized()
    {
        var connectionString = await fixture.CreateDatabaseAsync("auth_historyless");
        await using (var auth = ModuleRuntime.All.Single(runtime => runtime.ModuleName == "Auth").CreateContext(connectionString))
        {
            await auth.GetService<IMigrator>().MigrateAsync(AuthLegacyMigrationManifest.CanonicalInitialCreateId);
        }
        await ExecuteAsync(connectionString, "DROP TABLE [auth].[__EFMigrationsHistory];");

        var blocked = await RunMigratorAsync(connectionString, MigratorMode.Preflight);
        var adopted = await RunMigratorAsync(connectionString, explicitAuthAdoption: true);

        blocked.Result.Should().Be("failed");
        blocked.AuthLegacyAdoption!.Classification.Should()
            .Be(AuthLegacyAdoptionClassification.ExplicitAdoptionRequired);
        AssertSucceeded(adopted);
        adopted.AuthLegacyAdoption!.Classification.Should()
            .Be(AuthLegacyAdoptionClassification.EnsureCreatedAdoption);
        await G02SqlServerAssertions.AssertCurrentHistoriesAsync(connectionString, LoadManifest());
    }

    [Fact]
    public async Task Partial_Auth_legacy_history_fails_closed_without_rewriting_source_or_target()
    {
        var connectionString = await fixture.CreateDatabaseAsync("auth_partial_legacy");
        await using (var auth = ModuleRuntime.All.Single(runtime => runtime.ModuleName == "Auth").CreateContext(connectionString))
        {
            await auth.GetService<IMigrator>().MigrateAsync(AuthLegacyMigrationManifest.CanonicalInitialCreateId);
        }
        await ExecuteAsync(connectionString, """
            DROP TABLE [auth].[__EFMigrationsHistory];
            CREATE TABLE [dbo].[__EFMigrationsHistory] (
                [MigrationId] nvarchar(150) NOT NULL PRIMARY KEY,
                [ProductVersion] nvarchar(32) NOT NULL);
            """);
        foreach (var id in AuthLegacyMigrationManifest.PreSquashMigrationIds.Take(13))
        {
            await InsertHistoryAsync(connectionString, "dbo", id, "8.0.11");
        }

        var result = await RunMigratorAsync(connectionString);

        result.Result.Should().Be("failed");
        result.FailurePoint.Should().Be("auth-legacy-adoption");
        result.Errors.Should().Contain(error => error.Contains("mixed or incomplete", StringComparison.OrdinalIgnoreCase));
        (await HistoryExistsAsync(connectionString, "auth")).Should().BeFalse();
        (await ScalarAsync<int>(connectionString, "SELECT COUNT(*) FROM [dbo].[__EFMigrationsHistory];"))
            .Should().Be(13);
    }

    [Fact]
    public async Task Previous_release_upgrades_to_latest_without_losing_existing_data()
    {
        var connectionString = await fixture.CreateDatabaseAsync("upgrade");
        foreach (var runtime in ModuleRuntime.All)
        {
            await using var context = runtime.CreateContext(connectionString);
            var ids = runtime.CurrentMigrationRows(context).Select(row => row.MigrationId).ToArray();
            await context.GetService<IMigrator>().MigrateAsync(ids[^2]);
        }
        var partyId = Guid.NewGuid();
        await ExecuteAsync(connectionString, $"""
            INSERT INTO [crm].[Parties]
                ([Id], [TenantId], [PartyCode], [Name], [LegalStructure], [Status], [CreatedAt], [UpdatedAt])
            VALUES
                ('{partyId}', '{Guid.NewGuid()}', N'G02-PARTY', N'Upgrade sentinel', 0, 0, SYSUTCDATETIME(), SYSUTCDATETIME());
            """);

        var result = await RunMigratorAsync(connectionString);
        var rerun = await RunMigratorAsync(connectionString);

        AssertSucceeded(result);
        AssertSucceeded(rerun);
        rerun.Modules.Should().OnlyContain(module => module.AppliedIds.Count == 0);
        (await ScalarAsync<string>(connectionString, $"SELECT [Name] FROM [crm].[Parties] WHERE [Id] = '{partyId}';"))
            .Should().Be("Upgrade sentinel");
        (await ScalarAsync<string>(connectionString, """
            SELECT TYPE_NAME(c.user_type_id)
            FROM sys.columns c
            WHERE c.object_id = OBJECT_ID(N'[crm].[Parties]') AND c.name = N'CreatedAt';
            """)).Should().Be("datetimeoffset");
        await AssertCurrentHistoriesAsync(connectionString);
    }

    [Fact]
    public async Task Concurrent_migrators_serialize_and_lock_timeout_is_explicit()
    {
        var connectionString = await fixture.CreateDatabaseAsync("concurrent");

        var results = await Task.WhenAll(RunMigratorAsync(connectionString), RunMigratorAsync(connectionString));

        foreach (var result in results) AssertSucceeded(result);
        results.Select(result => result.Modules.Sum(module => module.AppliedIds.Count))
            .Should().BeEquivalentTo([0, 19]);
        await AssertCurrentHistoriesAsync(connectionString);

        await using var owner = await DatabaseMigrationLock.AcquireAsync(connectionString, TimeSpan.FromSeconds(2), CancellationToken.None);
        var competing = async () =>
        {
            await using var ignored = await DatabaseMigrationLock.AcquireAsync(
                connectionString,
                TimeSpan.FromMilliseconds(100),
                CancellationToken.None);
        };
        await competing.Should().ThrowAsync<InvalidOperationException>().WithMessage("*0.1 seconds*");
    }

    [Fact]
    public async Task Module_failure_stops_later_modules_and_same_database_can_roll_forward()
    {
        var connectionString = await fixture.CreateDatabaseAsync("failure");
        var failed = await RunMigratorAsync(
            connectionString,
            migrateModule: async (runtime, context, cancellationToken) =>
            {
                if (runtime.ModuleName == "CRM") throw new InvalidOperationException("injected phase-7 failure");
                await context.Database.MigrateAsync(cancellationToken);
            });

        failed.Result.Should().Be("failed");
        failed.FailurePoint.Should().Be("module:CRM");
        failed.Modules.Select(module => module.Module).Should().Equal("Auth");
        (await HistoryExistsAsync(connectionString, "Auth")).Should().BeTrue();
        (await HistoryExistsAsync(connectionString, "registry")).Should().BeFalse();

        var resumed = await RunMigratorAsync(connectionString);

        AssertSucceeded(resumed);
        await AssertCurrentHistoriesAsync(connectionString);
    }

    [Fact]
    public async Task Runtime_identity_can_read_and_write_module_schemas_but_cannot_execute_DDL()
    {
        var connectionString = await fixture.CreateDatabaseAsync("permissions");
        AssertSucceeded(await RunMigratorAsync(connectionString));
        var database = new SqlConnectionStringBuilder(connectionString).InitialCatalog;
        var login = $"g02_runtime_{Guid.NewGuid():N}";
        var password = $"G02_Runtime!{Guid.NewGuid():N}aA1";
        await ExecuteAsync(fixture.MasterConnectionString, $"CREATE LOGIN [{login}] WITH PASSWORD = '{password}';");
        await ExecuteAsync(connectionString, "CREATE TABLE [auth].[RuntimeDmlProbe] ([Id] int NOT NULL PRIMARY KEY, [Value] nvarchar(50) NOT NULL);");
        await ExecuteAsync(connectionString, $"""
            CREATE USER [{login}] FOR LOGIN [{login}];
            GRANT CONNECT TO [{login}];
            GRANT SELECT, INSERT, UPDATE, DELETE ON SCHEMA::[auth] TO [{login}];
            GRANT SELECT, INSERT, UPDATE, DELETE ON SCHEMA::[crm] TO [{login}];
            GRANT SELECT, INSERT, UPDATE, DELETE ON SCHEMA::[registry] TO [{login}];
            GRANT SELECT, INSERT, UPDATE, DELETE ON SCHEMA::[holdings] TO [{login}];
            GRANT SELECT, INSERT, UPDATE, DELETE ON SCHEMA::[transaction] TO [{login}];
            """);
        var runtimeConnection = new SqlConnectionStringBuilder(connectionString)
        {
            IntegratedSecurity = false,
            UserID = login,
            Password = password,
            InitialCatalog = database
        }.ConnectionString;

        foreach (var module in LoadManifest().Modules)
        {
            (await ScalarAsync<int>(runtimeConnection, $"SELECT COUNT(*) FROM [{module.Schema}].[{module.HistoryTable}];"))
                .Should().Be(module.Migrations.Count);
        }
        (await ScalarAsync<int>(runtimeConnection, "SELECT HAS_PERMS_BY_NAME(N'auth', N'SCHEMA', N'SELECT');"))
            .Should().Be(1);
        (await ScalarAsync<int>(runtimeConnection, "SELECT HAS_PERMS_BY_NAME(N'auth', N'SCHEMA', N'ALTER');"))
            .Should().Be(0);
        await ExecuteAsync(runtimeConnection, "INSERT INTO [auth].[RuntimeDmlProbe] ([Id], [Value]) VALUES (1, N'created');");
        await ExecuteAsync(runtimeConnection, "UPDATE [auth].[RuntimeDmlProbe] SET [Value] = N'updated' WHERE [Id] = 1;");
        await ExecuteAsync(runtimeConnection, "DELETE FROM [auth].[RuntimeDmlProbe] WHERE [Id] = 1;");
        AssertSucceeded(await RunMigratorAsync(runtimeConnection, MigratorMode.Validate));
        var ddl = () => ExecuteAsync(runtimeConnection, "CREATE TABLE [auth].[RuntimeMustNotCreate] ([Id] int NOT NULL);");
        await ddl.Should().ThrowAsync<SqlException>();
    }

    [Fact]
    public async Task Nonproduction_rollout_rehearsal_verifies_restore_point_and_full_job_sequence()
    {
        var connectionString = await fixture.CreateDatabaseAsync("rollout_rehearsal");
        var database = new SqlConnectionStringBuilder(connectionString).InitialCatalog;
        var backup = $"/var/opt/mssql/data/{database}.bak";

        var preflight = await RunMigratorAsync(connectionString, MigratorMode.Preflight);
        AssertSucceeded(preflight);
        preflight.HistoryBootstrap!.Classification.Should().Be(HistoryBootstrapClassification.Fresh);
        await ExecuteAsync(
            fixture.MasterConnectionString,
            $"BACKUP DATABASE [{database}] TO DISK = N'{backup}' WITH COPY_ONLY, INIT, CHECKSUM;");
        await ExecuteAsync(
            fixture.MasterConnectionString,
            $"RESTORE VERIFYONLY FROM DISK = N'{backup}' WITH CHECKSUM;");

        var applied = await RunMigratorAsync(connectionString);
        var validated = await RunMigratorAsync(connectionString, MigratorMode.Validate);
        var rerun = await RunMigratorAsync(connectionString);

        AssertSucceeded(applied);
        AssertSucceeded(validated);
        AssertSucceeded(rerun);
        rerun.Modules.Should().OnlyContain(module => module.AppliedIds.Count == 0);
        await G02SqlServerAssertions.AssertCurrentHistoriesAsync(connectionString, LoadManifest());
    }

    private static readonly string[] ExpectedModules = ["Auth", "CRM", "Registry", "Holdings", "Transaction"];

    private static void AssertSucceeded(MigratorReport report) =>
        report.Result.Should().Be(
            "succeeded",
            "failure point {0}; errors: {1}",
            report.FailurePoint ?? "<none>",
            string.Join(" | ", report.Errors));

    private static async Task<MigratorReport> RunMigratorAsync(
        string connectionString,
        MigratorMode mode = MigratorMode.Apply,
        bool explicitAuthAdoption = false,
        Func<ModuleRuntime, DbContext, CancellationToken, Task>? migrateModule = null)
    {
        var contexts = ModuleRuntime.All.ToDictionary(
            runtime => runtime.ModuleName,
            runtime => runtime.CreateContext(connectionString),
            StringComparer.Ordinal);
        try
        {
            var connections = ModuleRuntime.All.ToDictionary(
                runtime => runtime.ModuleName,
                _ => connectionString,
                StringComparer.Ordinal);
            var options = new MigratorOptions(
                mode,
                Path.Combine(Path.GetTempPath(), $"g02-{Guid.NewGuid():N}.json"),
                explicitAuthAdoption,
                Path.GetTempPath(),
                ReleaseManifestPath());
            return await new DatabaseMigratorRunner(
                LoadManifest(),
                options,
                connections,
                contexts,
                migrateModule).RunAsync(CancellationToken.None);
        }
        finally
        {
            foreach (var context in contexts.Values) await context.DisposeAsync();
        }
    }

    private static async Task AssertCurrentHistoriesAsync(string connectionString)
        => await G02SqlServerAssertions.AssertCurrentHistoriesAsync(connectionString, LoadManifest());

    private static async Task InsertHistoryAsync(string connectionString, string schema, string id, string version)
    {
        await using var connection = new SqlConnection(connectionString);
        await connection.OpenAsync();
        await using var command = connection.CreateCommand();
        command.CommandText = $"INSERT INTO [{schema}].[__EFMigrationsHistory] ([MigrationId], [ProductVersion]) VALUES (@id, @version);";
        command.Parameters.AddWithValue("@id", id);
        command.Parameters.AddWithValue("@version", version);
        await command.ExecuteNonQueryAsync();
    }

    private static async Task<bool> HistoryExistsAsync(string connectionString, string schema) =>
        await ScalarAsync<int>(connectionString, $"SELECT CASE WHEN OBJECT_ID(N'[{schema}].[__EFMigrationsHistory]', N'U') IS NULL THEN 0 ELSE 1 END;") == 1;

    private static async Task ExecuteAsync(string connectionString, string sql)
    {
        await using var connection = new SqlConnection(connectionString);
        await connection.OpenAsync();
        await using var command = connection.CreateCommand();
        command.CommandText = sql;
        await command.ExecuteNonQueryAsync();
    }

    private static async Task<T> ScalarAsync<T>(string connectionString, string sql)
    {
        await using var connection = new SqlConnection(connectionString);
        await connection.OpenAsync();
        await using var command = connection.CreateCommand();
        command.CommandText = sql;
        return (T)Convert.ChangeType(await command.ExecuteScalarAsync() ?? throw new InvalidOperationException("Scalar query returned null."), typeof(T));
    }

    private static async Task<IReadOnlyList<string>> QueryStringsAsync(string connectionString, string sql)
    {
        await using var connection = new SqlConnection(connectionString);
        await connection.OpenAsync();
        await using var command = connection.CreateCommand();
        command.CommandText = sql;
        await using var reader = await command.ExecuteReaderAsync();
        var values = new List<string>();
        while (await reader.ReadAsync()) values.Add(reader.GetString(0));
        return values;
    }

    private static MigrationManifest LoadManifest() => MigrationManifest.Load(Path.Combine(
        RepositoryRoot(), "src", "DatabaseMigrator", "IFX.DatabaseMigrator", "migration-manifest.json"));

    private static string ReleaseManifestPath() => Path.Combine(RepositoryRoot(), "deployment", "release-manifest.json");

    private static string RepositoryRoot()
    {
        var directory = new DirectoryInfo(AppContext.BaseDirectory);
        while (directory is not null && !File.Exists(Path.Combine(directory.FullName, "IFX.sln"))) directory = directory.Parent;
        return directory?.FullName ?? throw new InvalidOperationException("Repository root not found.");
    }
}
