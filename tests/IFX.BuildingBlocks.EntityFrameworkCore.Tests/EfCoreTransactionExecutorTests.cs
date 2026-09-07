using IFX.BuildingBlocks.Application.Transactions;
using IFX.BuildingBlocks.EntityFrameworkCore.Transactions;
using Microsoft.Data.Sqlite;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Storage;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Logging.Abstractions;

namespace IFX.BuildingBlocks.EntityFrameworkCore.Tests;

public sealed class EfCoreTransactionExecutorTests
{
    [Fact]
    public async Task Persistence_atomically_saves_business_and_pending_records()
    {
        await using var fixture = await DatabaseFixture.CreateAsync();
        fixture.Context.Items.Add(new TestItem { Id = 1, Name = "created", Version = 1 });
        var executor = new TestExecutor(fixture.Context);
        var prepareCalls = 0;

        await executor.ExecutePersistenceAsync(
            _ =>
            {
                prepareCalls++;
                fixture.Context.Items.Add(new TestItem { Id = 2, Name = "pending record", Version = 1 });
                return Task.CompletedTask;
            },
            CancellationToken.None);

        prepareCalls.Should().Be(1);
        (await fixture.Context.Items.AsNoTracking().OrderBy(item => item.Id).ToListAsync())
            .Select(item => item.Name)
            .Should().Equal("created", "pending record");
    }

    [Fact]
    public async Task Failure_rolls_back_and_clears_tracked_changes()
    {
        await using var fixture = await DatabaseFixture.CreateAsync();
        fixture.Context.Items.Add(new TestItem { Id = 1, Name = "not committed", Version = 1 });
        var executor = new TestExecutor(fixture.Context);

        Func<Task> act = () => executor.ExecutePersistenceAsync(
            _ => throw new InvalidOperationException("boom"),
            CancellationToken.None);

        await act.Should().ThrowAsync<InvalidOperationException>();
        fixture.Context.ChangeTracker.Entries().Should().BeEmpty();
        (await fixture.Context.Items.AsNoTracking().CountAsync()).Should().Be(0);
    }

    [Fact]
    public async Task Optimistic_concurrency_failure_is_translated_without_leaking_EF()
    {
        await using var connection = new SqliteConnection("Data Source=:memory:");
        await connection.OpenAsync();
        var options = new DbContextOptionsBuilder<TestDbContext>().UseSqlite(connection).Options;
        await using var first = new TestDbContext(options);
        await first.Database.EnsureCreatedAsync();
        first.Items.Add(new TestItem { Id = 1, Name = "original", Version = 1 });
        await first.SaveChangesAsync();
        first.ChangeTracker.Clear();

        var stale = await first.Items.SingleAsync(item => item.Id == 1);
        await using (var second = new TestDbContext(options))
        {
            var current = await second.Items.SingleAsync(item => item.Id == 1);
            current.Version = 2;
            await second.SaveChangesAsync();
        }

        stale.Name = "stale write";
        var executor = new TestExecutor(first);

        Func<Task> act = () => executor.ExecutePersistenceAsync(
            _ => Task.CompletedTask,
            CancellationToken.None);

        var exception = await act.Should().ThrowAsync<ConcurrencyConflictException>();
        exception.Which.OwnerType.Should().Be(typeof(TestOwner));
        exception.Which.InnerException.Should().BeOfType<DbUpdateConcurrencyException>();
        first.ChangeTracker.Entries().Should().BeEmpty();
    }

    [Fact]
    public async Task Successful_execution_begins_commits_and_disposes_exactly_once()
    {
        await using var fixture = await DatabaseFixture.CreateAsync();
        var transaction = CreateTransaction();
        var executor = new FaultInjectingExecutor(fixture.Context, transaction.Object);

        await executor.ExecuteAtomicAsync(_ => Task.CompletedTask, CancellationToken.None);

        executor.BeginCalls.Should().Be(1);
        executor.SaveCalls.Should().Be(1);
        transaction.Verify(item => item.CommitAsync(It.IsAny<CancellationToken>()), Times.Once);
        transaction.Verify(item => item.RollbackAsync(It.IsAny<CancellationToken>()), Times.Never);
        transaction.Verify(item => item.DisposeAsync(), Times.Once);
    }

    [Fact]
    public async Task Save_failure_rolls_back_once_and_preserves_the_original_exception()
    {
        await using var fixture = await DatabaseFixture.CreateAsync();
        var transaction = CreateTransaction();
        var expected = new InvalidOperationException("save failed");
        var executor = new FaultInjectingExecutor(fixture.Context, transaction.Object)
        {
            SaveFailure = expected
        };

        Func<Task> act = () => executor.ExecutePersistenceAsync(
            _ => Task.CompletedTask,
            CancellationToken.None);

        (await act.Should().ThrowAsync<InvalidOperationException>()).Which.Should().BeSameAs(expected);
        transaction.Verify(item => item.RollbackAsync(It.IsAny<CancellationToken>()), Times.Once);
        transaction.Verify(item => item.CommitAsync(It.IsAny<CancellationToken>()), Times.Never);
        transaction.Verify(item => item.DisposeAsync(), Times.Once);
        executor.ClearCalls.Should().Be(1);
    }

    [Fact]
    public async Task Commit_failure_is_reported_as_unknown_and_does_not_claim_rollback()
    {
        await using var fixture = await DatabaseFixture.CreateAsync();
        var transaction = CreateTransaction();
        var expected = new InvalidOperationException("connection lost after commit request");
        transaction.Setup(item => item.CommitAsync(It.IsAny<CancellationToken>())).ThrowsAsync(expected);
        var executor = new FaultInjectingExecutor(fixture.Context, transaction.Object);

        Func<Task> act = () => executor.ExecutePersistenceAsync(
            _ => Task.CompletedTask,
            CancellationToken.None);

        var failure = await act.Should().ThrowAsync<TransactionCommitOutcomeUnknownException>();
        failure.Which.InnerException.Should().BeSameAs(expected);
        transaction.Verify(item => item.RollbackAsync(It.IsAny<CancellationToken>()), Times.Never);
        transaction.Verify(item => item.DisposeAsync(), Times.Once);
    }

    [Fact]
    public async Task Rollback_and_dispose_cleanup_failures_never_replace_the_primary_failure()
    {
        await using var fixture = await DatabaseFixture.CreateAsync();
        var transaction = CreateTransaction();
        transaction.Setup(item => item.RollbackAsync(It.IsAny<CancellationToken>()))
            .ThrowsAsync(new IOException("rollback cleanup"));
        transaction.Setup(item => item.DisposeAsync())
            .Returns(ValueTask.FromException(new IOException("dispose cleanup")));
        var expected = new InvalidOperationException("primary failure");
        var logger = new Mock<ILogger>();
        var executor = new FaultInjectingExecutor(fixture.Context, transaction.Object, logger.Object)
        {
            SaveFailure = expected
        };

        Func<Task> act = () => executor.ExecuteAtomicAsync(
            _ => Task.CompletedTask,
            CancellationToken.None);

        (await act.Should().ThrowAsync<InvalidOperationException>()).Which.Should().BeSameAs(expected);
        transaction.Verify(item => item.RollbackAsync(It.IsAny<CancellationToken>()), Times.Once);
        transaction.Verify(item => item.DisposeAsync(), Times.Once);
    }

    [Fact]
    public async Task Concurrent_use_fails_fast_without_disturbing_the_active_execution()
    {
        await using var fixture = await DatabaseFixture.CreateAsync();
        var transaction = CreateTransaction();
        var executor = new FaultInjectingExecutor(fixture.Context, transaction.Object);
        var entered = new TaskCompletionSource(TaskCreationOptions.RunContinuationsAsynchronously);
        var release = new TaskCompletionSource(TaskCreationOptions.RunContinuationsAsynchronously);
        var active = executor.ExecuteAtomicAsync(
            async _ =>
            {
                entered.SetResult();
                await release.Task;
            },
            CancellationToken.None);
        await entered.Task;

        Func<Task> concurrent = () => executor.ExecuteAtomicAsync(
            _ => Task.CompletedTask,
            CancellationToken.None);

        await concurrent.Should().ThrowAsync<InvalidOperationException>()
            .WithMessage("*concurrent or nested execution*");
        release.SetResult();
        await active;
        transaction.Verify(item => item.CommitAsync(It.IsAny<CancellationToken>()), Times.Once);
    }

    [Fact]
    public async Task Relational_savepoint_rolls_back_only_changes_after_the_savepoint()
    {
        await using var fixture = await DatabaseFixture.CreateAsync();
        await using var transaction = await fixture.Context.Database.BeginTransactionAsync();
        fixture.Context.Items.Add(new TestItem { Id = 1, Name = "before", Version = 1 });
        await fixture.Context.SaveChangesAsync();
        await transaction.CreateSavepointAsync("before_optional_work");

        fixture.Context.Items.Add(new TestItem { Id = 2, Name = "after", Version = 1 });
        await fixture.Context.SaveChangesAsync();
        await transaction.RollbackToSavepointAsync("before_optional_work");
        fixture.Context.ChangeTracker.Clear();
        await transaction.CommitAsync();

        (await fixture.Context.Items.AsNoTracking().Select(item => item.Name).ToListAsync())
            .Should().Equal("before");
    }

    [Fact]
    public async Task Transient_persistence_retry_preserves_handler_changes_and_recreates_pending_record_once()
    {
        await using var fixture = await DatabaseFixture.CreateAsync();
        fixture.Context.Items.Add(new TestItem { Id = 1, Name = "business", Version = 1 });
        var executor = new RetryingTestExecutor(fixture.Context);
        var prepareCalls = 0;

        await executor.ExecutePersistenceAsync(
            _ =>
            {
                prepareCalls++;
                fixture.Context.Items.Add(new TestItem { Id = 2, Name = "pending", Version = 1 });
                return Task.CompletedTask;
            },
            CancellationToken.None);

        prepareCalls.Should().Be(2);
        executor.SaveCalls.Should().Be(2);
        (await fixture.Context.Items.AsNoTracking().OrderBy(item => item.Id).Select(item => item.Name).ToListAsync())
            .Should().Equal("business", "pending");
    }

    private static Mock<IDbContextTransaction> CreateTransaction()
    {
        var transaction = new Mock<IDbContextTransaction>();
        transaction.Setup(item => item.CommitAsync(It.IsAny<CancellationToken>())).Returns(Task.CompletedTask);
        transaction.Setup(item => item.RollbackAsync(It.IsAny<CancellationToken>())).Returns(Task.CompletedTask);
        transaction.Setup(item => item.DisposeAsync()).Returns(ValueTask.CompletedTask);
        return transaction;
    }

    private sealed class TestOwner : ITransactionOwner;

    private sealed class TestExecutor(TestDbContext context)
        : EfCoreTransactionExecutor<TestOwner, TestDbContext>(context, NullLogger.Instance);

    private sealed class FaultInjectingExecutor : EfCoreTransactionExecutor<TestOwner, TestDbContext>
    {
        private readonly IDbContextTransaction _transaction;

        public FaultInjectingExecutor(
            TestDbContext context,
            IDbContextTransaction transaction,
            ILogger? logger = null)
            : base(context, logger ?? NullLogger.Instance)
        {
            _transaction = transaction;
        }

        public Exception? SaveFailure { get; init; }

        public int BeginCalls { get; private set; }

        public int SaveCalls { get; private set; }

        public int ClearCalls { get; private set; }

        protected override Task ExecuteWithStrategyAsync(Func<Task> operationAsync) => operationAsync();

        protected override Task<IDbContextTransaction> BeginTransactionAsync(CancellationToken cancellationToken)
        {
            BeginCalls++;
            return Task.FromResult(_transaction);
        }

        protected override Task SaveChangesAsync(CancellationToken cancellationToken)
        {
            SaveCalls++;
            return SaveFailure is null ? Task.CompletedTask : Task.FromException(SaveFailure);
        }

        protected override void ClearChanges() => ClearCalls++;
    }

    private sealed class RetryingTestExecutor(TestDbContext context)
        : EfCoreTransactionExecutor<TestOwner, TestDbContext>(context, NullLogger.Instance)
    {
        public int SaveCalls { get; private set; }

        protected override async Task ExecuteWithStrategyAsync(Func<Task> operationAsync)
        {
            try
            {
                await operationAsync();
            }
            catch (RetryableTestException)
            {
                await operationAsync();
            }
        }

        protected override Task SaveChangesAsync(CancellationToken cancellationToken)
        {
            SaveCalls++;
            return SaveCalls == 1
                ? Task.FromException(new RetryableTestException())
                : base.SaveChangesAsync(cancellationToken);
        }
    }

    private sealed class RetryableTestException : Exception;

    private sealed class TestDbContext(DbContextOptions<TestDbContext> options) : DbContext(options)
    {
        public DbSet<TestItem> Items => Set<TestItem>();

        protected override void OnModelCreating(ModelBuilder modelBuilder)
        {
            modelBuilder.Entity<TestItem>().Property(item => item.Version).IsConcurrencyToken();
        }
    }

    private sealed class TestItem
    {
        public int Id { get; set; }

        public string Name { get; set; } = string.Empty;

        public int Version { get; set; }
    }

    private sealed class DatabaseFixture : IAsyncDisposable
    {
        private DatabaseFixture(SqliteConnection connection, TestDbContext context)
        {
            Connection = connection;
            Context = context;
        }

        private SqliteConnection Connection { get; }

        public TestDbContext Context { get; }

        public static async Task<DatabaseFixture> CreateAsync()
        {
            var connection = new SqliteConnection("Data Source=:memory:");
            await connection.OpenAsync();
            var context = new TestDbContext(
                new DbContextOptionsBuilder<TestDbContext>().UseSqlite(connection).Options);
            await context.Database.EnsureCreatedAsync();
            return new DatabaseFixture(connection, context);
        }

        public async ValueTask DisposeAsync()
        {
            await Context.DisposeAsync();
            await Connection.DisposeAsync();
        }
    }
}
