using IFX.BuildingBlocks.Application.Behaviors;
using IFX.BuildingBlocks.Application.Commands;
using IFX.BuildingBlocks.Application.Events;
using IFX.BuildingBlocks.Application.Results;
using IFX.BuildingBlocks.Application.Transactions;
using IFX.BuildingBlocks.EntityFrameworkCore.Transactions;
using MediatR;
using Microsoft.Data.Sqlite;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging.Abstractions;

namespace IFX.BuildingBlocks.EntityFrameworkCore.Tests;

public sealed class InboxProfileConformanceTests
{
    private static readonly Guid TenantId = Guid.Parse("62ba888f-9d6e-4f8e-bd3f-bff480d32881");

    [Fact]
    public async Task New_event_atomically_saves_business_change_and_completion_then_duplicate_is_a_no_op()
    {
        await using var fixture = await InboxDatabaseFixture.CreateAsync();
        var metadata = new IntegrationEventMetadata(
            Guid.Parse("6b125dc2-eb46-4dd5-a6fd-c95af92b387b"),
            TenantId,
            "correlation",
            "causation");

        var first = await ExecuteAsync(fixture.Context, new InboxCommand("holdings-projection", metadata));
        fixture.Context.ChangeTracker.Clear();
        var duplicate = await ExecuteAsync(fixture.Context, new InboxCommand("holdings-projection", metadata));

        first.IsSuccess.Should().BeTrue();
        first.WasDuplicate.Should().BeFalse();
        duplicate.IsSuccess.Should().BeTrue();
        duplicate.WasDuplicate.Should().BeTrue();
        (await fixture.Context.BusinessRecords.AsNoTracking().CountAsync()).Should().Be(1);
        (await fixture.Context.InboxRecords.AsNoTracking().CountAsync()).Should().Be(1);
    }

    [Fact]
    public async Task Business_rejection_rolls_back_business_change_and_does_not_record_completion()
    {
        await using var fixture = await InboxDatabaseFixture.CreateAsync();
        var command = new InboxCommand(
            "holdings-projection",
            new IntegrationEventMetadata(Guid.NewGuid(), TenantId, null, null),
            Reject: true);

        var result = await ExecuteAsync(fixture.Context, command);

        result.IsSuccess.Should().BeFalse();
        (await fixture.Context.BusinessRecords.AsNoTracking().CountAsync()).Should().Be(0);
        (await fixture.Context.InboxRecords.AsNoTracking().CountAsync()).Should().Be(0);
    }

    [Fact]
    public async Task Composite_consumer_and_event_identity_rejects_concurrent_duplicate_completion()
    {
        await using var fixture = await InboxDatabaseFixture.CreateAsync();
        var eventId = Guid.NewGuid();
        var start = new TaskCompletionSource(TaskCreationOptions.RunContinuationsAsynchronously);

        var attempts = Enumerable.Range(0, 2).Select(async _ =>
        {
            await using var context = fixture.CreateContext();
            context.InboxRecords.Add(new InboxRecord
            {
                Id = Guid.NewGuid(),
                ConsumerId = "holdings-projection",
                EventId = eventId,
                CompletedAtUtc = DateTimeOffset.UtcNow
            });
            await start.Task;

            try
            {
                await SaveWithBusyRetryAsync(context);
                return (Exception?)null;
            }
            catch (Exception exception)
            {
                return exception;
            }
        }).ToArray();

        start.SetResult();
        var outcomes = await Task.WhenAll(attempts);

        outcomes.Count(exception => exception is null).Should().Be(1);
        outcomes.Single(exception => exception is not null).Should().BeOfType<DbUpdateException>();
        await using var verification = fixture.CreateContext();
        (await verification.InboxRecords.AsNoTracking().CountAsync()).Should().Be(1);
    }

    [Fact]
    public async Task Module_local_idempotency_identity_rejects_duplicate_request_but_not_another_tenant()
    {
        await using var fixture = await InboxDatabaseFixture.CreateAsync();
        var identity = IdempotencyIdentity.For<InboxCommand>(TenantId, "client-request-42");
        fixture.Context.IdempotencyRecords.Add(IdempotencyRecord.From(identity));
        await fixture.Context.SaveChangesAsync();
        fixture.Context.ChangeTracker.Clear();

        fixture.Context.IdempotencyRecords.Add(IdempotencyRecord.From(identity));
        Func<Task> duplicate = () => fixture.Context.SaveChangesAsync();

        await duplicate.Should().ThrowAsync<DbUpdateException>();
        fixture.Context.ChangeTracker.Clear();
        var anotherTenant = identity with { TenantId = Guid.NewGuid() };
        fixture.Context.IdempotencyRecords.Add(IdempotencyRecord.From(anotherTenant));
        await fixture.Context.SaveChangesAsync();

        (await fixture.Context.IdempotencyRecords.AsNoTracking().CountAsync()).Should().Be(2);
        IdempotencyPolicy.MinimumRetention.Should().Be(TimeSpan.FromDays(7));
    }

    [Fact]
    public async Task Commit_response_lost_is_reconciled_as_a_duplicate_without_reapplying_business_change()
    {
        await using var fixture = await InboxDatabaseFixture.CreateAsync();
        var command = new InboxCommand(
            "holdings-projection",
            new IntegrationEventMetadata(Guid.NewGuid(), TenantId, "correlation", "causation"));

        Func<Task> lostResponse = () => ExecuteAsync(
            fixture.Context,
            command,
            new CommitResponseLostExecutor(fixture.Context));

        await lostResponse.Should().ThrowAsync<TransactionCommitOutcomeUnknownException>();
        fixture.Context.ChangeTracker.Clear();
        (await fixture.Context.BusinessRecords.AsNoTracking().CountAsync()).Should().Be(1);
        (await fixture.Context.InboxRecords.AsNoTracking().CountAsync()).Should().Be(1);

        var reconciled = await ExecuteAsync(fixture.Context, command);

        reconciled.WasDuplicate.Should().BeTrue();
        (await fixture.Context.BusinessRecords.AsNoTracking().CountAsync()).Should().Be(1);
        (await fixture.Context.InboxRecords.AsNoTracking().CountAsync()).Should().Be(1);
    }

    private static async Task SaveWithBusyRetryAsync(InboxDbContext context)
    {
        for (var attempt = 0; ; attempt++)
        {
            try
            {
                await context.SaveChangesAsync();
                return;
            }
            catch (DbUpdateException exception)
                when (attempt < 10 && exception.InnerException is SqliteException { SqliteErrorCode: 5 or 6 })
            {
                await Task.Delay(20);
            }
        }
    }

    private static async Task<InboxResult> ExecuteAsync(
        InboxDbContext context,
        InboxCommand command,
        ITransactionExecutor? executor = null)
    {
        executor ??= new InboxExecutor(context);
        var participant = new InboxCompletionParticipant(context);
        var resolver = new Mock<ITransactionExecutorResolver>();
        resolver.Setup(item => item.Resolve(typeof(InboxCommand), typeof(InboxOwner))).Returns(executor);
        resolver.Setup(item => item.ResolveParticipants(typeof(InboxOwner))).Returns([participant]);
        var behavior = new TransactionBehavior<InboxCommand, InboxResult>(
            resolver.Object,
            new NoOpEventBuffer(),
            NullLogger<TransactionBehavior<InboxCommand, InboxResult>>.Instance);

        return await behavior.Handle(
            command,
            async () =>
            {
                var duplicate = await context.InboxRecords.AnyAsync(
                    record => record.ConsumerId == command.ConsumerId &&
                              record.EventId == command.Metadata.EventId);
                if (duplicate)
                {
                    return InboxResult.Duplicate();
                }

                context.BusinessRecords.Add(new BusinessRecord
                {
                    Id = Guid.NewGuid(),
                    TenantId = command.Metadata.TenantId,
                    EventId = command.Metadata.EventId
                });
                return command.Reject ? InboxResult.Rejected() : InboxResult.Applied();
            },
            CancellationToken.None);
    }

    private sealed record InboxCommand(
        string ConsumerId,
        IntegrationEventMetadata Metadata,
        bool Reject = false) : ICommand<InboxResult, InboxOwner>
    {
        public TransactionProfile TransactionProfile => TransactionProfile.Inbox;
    }

    private sealed record InboxResult(
        bool IsSuccess,
        OperationErrorCategory ErrorCategory,
        bool WasDuplicate) : IOperationResult
    {
        public static InboxResult Applied() => new(true, OperationErrorCategory.None, false);

        public static InboxResult Duplicate() => new(true, OperationErrorCategory.None, true);

        public static InboxResult Rejected() => new(false, OperationErrorCategory.BusinessRule, false);
    }

    private sealed class InboxOwner : ITransactionOwner;

    private sealed class InboxExecutor(InboxDbContext context)
        : EfCoreTransactionExecutor<InboxOwner, InboxDbContext>(context, NullLogger.Instance);

    private sealed class CommitResponseLostExecutor(InboxDbContext context) : ITransactionExecutor
    {
        public Type OwnerType => typeof(InboxOwner);

        public Task ExecutePersistenceAsync(
            Func<CancellationToken, Task> prepareAsync,
            CancellationToken cancellationToken) => throw new NotSupportedException();

        public async Task ExecuteAtomicAsync(
            Func<CancellationToken, Task> operationAsync,
            CancellationToken cancellationToken)
        {
            await using var transaction = await context.Database.BeginTransactionAsync(cancellationToken);
            await operationAsync(cancellationToken);
            await context.SaveChangesAsync(cancellationToken);
            await transaction.CommitAsync(cancellationToken);
            throw new TransactionCommitOutcomeUnknownException(
                typeof(InboxOwner),
                new IOException("commit acknowledgement was lost"));
        }

        public ValueTask DiscardChangesAsync(CancellationToken cancellationToken)
        {
            context.ChangeTracker.Clear();
            return ValueTask.CompletedTask;
        }
    }

    private sealed class InboxCompletionParticipant(InboxDbContext context) : ITransactionParticipant
    {
        public Task PrepareAsync(object command, object? response, CancellationToken cancellationToken)
        {
            if (command is InboxCommand inboxCommand &&
                response is InboxResult { IsSuccess: true, WasDuplicate: false })
            {
                context.InboxRecords.Add(new InboxRecord
                {
                    Id = Guid.NewGuid(),
                    ConsumerId = inboxCommand.ConsumerId,
                    EventId = inboxCommand.Metadata.EventId,
                    CompletedAtUtc = DateTimeOffset.UtcNow
                });
            }

            return Task.CompletedTask;
        }
    }

    private sealed class NoOpEventBuffer : ICommittedEventBuffer
    {
        public void Add<TEvent>(TEvent @event) where TEvent : notnull
        {
        }

        public Task DispatchAfterCommitAsync(CancellationToken cancellationToken) => Task.CompletedTask;

        public void Clear()
        {
        }
    }

    private sealed class InboxDbContext(DbContextOptions<InboxDbContext> options) : DbContext(options)
    {
        public DbSet<BusinessRecord> BusinessRecords => Set<BusinessRecord>();

        public DbSet<InboxRecord> InboxRecords => Set<InboxRecord>();

        public DbSet<IdempotencyRecord> IdempotencyRecords => Set<IdempotencyRecord>();

        protected override void OnModelCreating(ModelBuilder modelBuilder)
        {
            modelBuilder.Entity<InboxRecord>()
                .HasIndex(record => new { record.ConsumerId, record.EventId })
                .IsUnique();
            modelBuilder.Entity<IdempotencyRecord>()
                .HasIndex(record => new { record.TenantId, record.CommandType, record.Key })
                .IsUnique();
        }
    }

    private sealed class BusinessRecord
    {
        public Guid Id { get; set; }

        public Guid TenantId { get; set; }

        public Guid EventId { get; set; }
    }

    private sealed class InboxRecord
    {
        public Guid Id { get; set; }

        public string ConsumerId { get; set; } = string.Empty;

        public Guid EventId { get; set; }

        public DateTimeOffset CompletedAtUtc { get; set; }
    }

    private sealed class IdempotencyRecord
    {
        public Guid Id { get; set; }

        public Guid TenantId { get; set; }

        public string CommandType { get; set; } = string.Empty;

        public string Key { get; set; } = string.Empty;

        public DateTimeOffset RetainUntilUtc { get; set; }

        public static IdempotencyRecord From(IdempotencyIdentity identity) => new()
        {
            Id = Guid.NewGuid(),
            TenantId = identity.TenantId,
            CommandType = identity.CommandType,
            Key = identity.Key,
            RetainUntilUtc = DateTimeOffset.UtcNow.Add(IdempotencyPolicy.MinimumRetention)
        };
    }

    private sealed class InboxDatabaseFixture : IAsyncDisposable
    {
        private readonly SqliteConnection _keeper;
        private readonly DbContextOptions<InboxDbContext> _options;

        private InboxDatabaseFixture(SqliteConnection keeper, DbContextOptions<InboxDbContext> options)
        {
            _keeper = keeper;
            _options = options;
            Context = new InboxDbContext(options);
        }

        public InboxDbContext Context { get; }

        public static async Task<InboxDatabaseFixture> CreateAsync()
        {
            var connectionString = $"Data Source=inbox-{Guid.NewGuid():N};Mode=Memory;Cache=Shared;Default Timeout=30";
            var keeper = new SqliteConnection(connectionString);
            await keeper.OpenAsync();
            var options = new DbContextOptionsBuilder<InboxDbContext>()
                .UseSqlite(connectionString)
                .Options;
            await using (var setup = new InboxDbContext(options))
            {
                await setup.Database.EnsureCreatedAsync();
            }

            return new InboxDatabaseFixture(keeper, options);
        }

        public InboxDbContext CreateContext() => new(_options);

        public async ValueTask DisposeAsync()
        {
            await Context.DisposeAsync();
            await _keeper.DisposeAsync();
        }
    }
}
