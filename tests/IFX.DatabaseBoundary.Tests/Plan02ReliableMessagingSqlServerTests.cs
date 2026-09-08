using System.Text.Json;
using FluentAssertions;
using IFX.BuildingBlocks.Application;
using IFX.BuildingBlocks.Application.Context;
using IFX.BuildingBlocks.Application.Transactions;
using IFX.Modules.Holdings.Application;
using IFX.Modules.Holdings.Application.Integrations;
using IFX.Modules.Holdings.Application.Interfaces;
using IFX.Modules.Holdings.Application.Ports;
using IFX.Modules.Holdings.Application.Transactions;
using IFX.Modules.Holdings.Domain.Repositories;
using IFX.Modules.Holdings.Infrastructure.Messaging;
using IFX.Modules.Holdings.Infrastructure.Integrations;
using IFX.Modules.Holdings.Infrastructure.Persistence;
using IFX.Modules.Holdings.Infrastructure.Repositories;
using IFX.Modules.Transaction.Contracts.V1.Events;
using IFX.Modules.Transaction.Infrastructure.Messaging;
using IFX.Modules.Transaction.Infrastructure.Persistence;
using IFX.Platform.Messaging.Contracts.Messaging;
using IFX.Platform.Messaging.Runtime;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Xunit;
using TxEntity = IFX.Modules.Transaction.Domain.Entities.Transaction;

namespace IFX.DatabaseBoundary.Tests;

[Collection(SqlServerMigrationCollection.Name)]
public sealed class Plan02ReliableMessagingSqlServerTests(SqlServerMigrationFixture fixture)
{
    [Fact]
    public async Task Transaction_business_state_and_outbox_commit_or_rollback_together()
    {
        var connectionString = await fixture.CreateDatabaseAsync("plan02_outbox_atomic");
        var options = new DbContextOptionsBuilder<TransactionDbContext>()
            .UseSqlServer(connectionString, sql => sql.MigrationsHistoryTable("__EFMigrationsHistory", "transaction"))
            .Options;
        await using var context = new TransactionDbContext(options);
        await context.Database.MigrateAsync();
        var execution = TestExecutionContextAccessor.ForTenant(Guid.NewGuid());
        var source = new BufferedIntegrationEventSource();
        var participant = new TransactionOutboxParticipant(context, source, new OutboxMessageFactory(execution), execution);

        var rolledBack = NewTransaction(execution.Current.TenantId!.Value);
        await using (var transaction = await context.Database.BeginTransactionAsync())
        {
            context.Transactions.Add(rolledBack);
            source.Add(ToEvent(rolledBack));
            await participant.PrepareAsync(new object(), new object(), CancellationToken.None);
            await context.SaveChangesAsync();
            await transaction.RollbackAsync();
        }
        context.ChangeTracker.Clear();
        (await context.Transactions.CountAsync()).Should().Be(0);
        (await context.OutboxMessages.CountAsync()).Should().Be(0);

        var committed = NewTransaction(execution.Current.TenantId!.Value);
        await using (var transaction = await context.Database.BeginTransactionAsync())
        {
            context.Transactions.Add(committed);
            source.Add(ToEvent(committed));
            await participant.PrepareAsync(new object(), new object(), CancellationToken.None);
            await context.SaveChangesAsync();
            await transaction.CommitAsync();
        }
        context.ChangeTracker.Clear();
        (await context.Transactions.CountAsync()).Should().Be(1);
        var outbox = await context.OutboxMessages.SingleAsync();
        outbox.EventType.Should().Be(TransactionProcessedV1.EventType);
        outbox.TenantId.Should().Be(execution.Current.TenantId);
        outbox.Payload.Contains("tenantId", StringComparison.OrdinalIgnoreCase).Should().BeFalse();
    }

    [Fact]
    public async Task Retry_reclaims_same_logical_message_and_stale_lease_cannot_complete()
    {
        var connectionString = await fixture.CreateDatabaseAsync("plan02_outbox_retry");
        var options = new DbContextOptionsBuilder<TransactionDbContext>()
            .UseSqlServer(connectionString, sql => sql.MigrationsHistoryTable("__EFMigrationsHistory", "transaction"))
            .Options;
        await using var context = new TransactionDbContext(options);
        await context.Database.MigrateAsync();
        var execution = TestExecutionContextAccessor.ForTenant(Guid.NewGuid());
        var source = new BufferedIntegrationEventSource();
        var participant = new TransactionOutboxParticipant(context, source, new OutboxMessageFactory(execution), execution);
        var business = NewTransaction(execution.Current.TenantId!.Value);
        context.Transactions.Add(business);
        source.Add(ToEvent(business));
        await participant.PrepareAsync(new object(), new object(), CancellationToken.None);
        await context.SaveChangesAsync();

        var store = new TransactionOutboxStore(context);
        var now = DateTimeOffset.UtcNow;
        var first = (await store.ClaimAsync(new OutboxClaimRequest("worker-a", now, now.AddMinutes(1), 10), CancellationToken.None)).Single();
        context.ChangeTracker.Clear();
        (await store.ClaimAsync(new OutboxClaimRequest("worker-b", now.AddSeconds(30), now.AddMinutes(2), 10), CancellationToken.None)).Should().BeEmpty();
        context.ChangeTracker.Clear();
        var second = (await store.ClaimAsync(new OutboxClaimRequest("worker-b", now.AddMinutes(2), now.AddMinutes(3), 10), CancellationToken.None)).Single();
        second.Message.Should().Be(first.Message);
        second.AttemptCount.Should().Be(2);
        await store.FailAsync(second, now.AddMinutes(2), "PoisonMessage", true, CancellationToken.None);
        context.ChangeTracker.Clear();
        var diagnostic = (await store.QueryAsync(new OutboxDiagnosticQuery(EventId: first.Message.Envelope.EventId), CancellationToken.None)).Single();
        diagnostic.State.Should().Be("DeadLettered");
        (await store.ReplayDeadLetterAsync(first.Message.Envelope.EventId, now.AddMinutes(3), CancellationToken.None)).Should().BeTrue();
        context.ChangeTracker.Clear();
        var third = (await store.ClaimAsync(new OutboxClaimRequest("worker-c", now.AddMinutes(3), now.AddMinutes(4), 10), CancellationToken.None)).Single();

        third.Message.Should().Be(first.Message);
        third.AttemptCount.Should().Be(3);
        Func<Task> staleCompletion = () => store.CompleteAsync(first, now, CancellationToken.None);
        await staleCompletion.Should().ThrowAsync<InvalidOperationException>();
        await store.CompleteAsync(third, now.AddMinutes(3), CancellationToken.None);
        (await context.OutboxMessages.SingleAsync()).State.Should().Be("Delivered");
    }

    [Fact]
    public async Task Durable_transport_adapter_and_inbox_apply_once_and_quarantine_bad_context()
    {
        var connectionString = await fixture.CreateDatabaseAsync("plan02_end_to_end");
        var services = new ServiceCollection();
        services.AddLogging();
        var execution = TestExecutionContextAccessor.ForTenant(Guid.NewGuid());
        services.AddSingleton<IExecutionContextAccessor>(execution);
        services.AddSingleton<IExecutionContextScopeFactory>(execution);
        services.AddMessagingRuntime();
        services.AddApplicationServices();
        services.AddApplicationPipeline();
        services.AddDbContext<HoldingsDbContext>(options => options.UseSqlServer(connectionString, sql => sql.MigrationsHistoryTable("__EFMigrationsHistory", "holdings")));
        services.AddScoped<IHoldingRepository, EfHoldingRepository>();
        services.AddScoped<IUnitOfWork, HoldingsUnitOfWork>();
        services.AddKeyedScoped<ITransactionExecutor, HoldingsTransactionExecutor>(typeof(HoldingsTransactionOwner));
        services.AddKeyedScoped<ITransactionParticipant, HoldingsInboxParticipant>(typeof(HoldingsTransactionOwner));
        services.AddScoped<IHoldingsInboxPort, HoldingsInboxPort>();
        services.AddScoped<IInboundIntegrationEventHandler, HoldingsInboundIntegrationEventHandler>();
        await using var provider = services.BuildServiceProvider();
        await using (var setup = provider.CreateAsyncScope())
        {
            await setup.ServiceProvider.GetRequiredService<HoldingsDbContext>().Database.MigrateAsync();
        }

        var tenantId = execution.Current.TenantId!.Value;
        var accountId = Guid.NewGuid();
        var classId = Guid.NewGuid();
        var eventId = Guid.NewGuid();
        var payload = new TransactionProcessedV1(Guid.NewGuid(), "Subscription", accountId, classId, null, 15m, 2m);
        var logical = new OutboxLogicalMessage(
            new EventEnvelope(eventId, TransactionProcessedV1.EventType, 1, DateTimeOffset.UtcNow, "ifx.transaction", EventEnvelope.TenantScope, tenantId, Guid.NewGuid(), Guid.NewGuid()),
            JsonSerializer.Serialize(payload, new JsonSerializerOptions(JsonSerializerDefaults.Web)));
        var transport = provider.GetRequiredService<IIntegrationEventSender>();

        await transport.SendAsync(logical, CancellationToken.None);
        await transport.SendAsync(logical, CancellationToken.None);

        await using (var verification = provider.CreateAsyncScope())
        {
            var context = verification.ServiceProvider.GetRequiredService<HoldingsDbContext>();
            (await context.Holdings.SingleAsync()).Units.Should().Be(15m);
            (await context.InboxMessages.CountAsync()).Should().Be(1);
        }

        var invalid = logical with
        {
            Envelope = new EventEnvelope(Guid.NewGuid(), TransactionProcessedV1.EventType, 1, DateTimeOffset.UtcNow, "ifx.registry", EventEnvelope.TenantScope, tenantId, Guid.NewGuid(), Guid.NewGuid())
        };
        await transport.SendAsync(invalid, CancellationToken.None);
        await using (var quarantineVerification = provider.CreateAsyncScope())
        {
            var context = quarantineVerification.ServiceProvider.GetRequiredService<HoldingsDbContext>();
            (await context.InboxMessages.CountAsync()).Should().Be(1);
            (await context.QuarantinedMessages.SingleAsync()).ReasonCode.Should().Be("G05-EVENT-PRODUCER-INVALID");
        }
    }

    private static TxEntity NewTransaction(Guid tenantId) => TxEntity.CreateSubscription(tenantId, Guid.NewGuid(), Guid.NewGuid(), Guid.NewGuid(), 100m, DateOnly.FromDateTime(DateTime.UtcNow));

    private static TransactionProcessedV1 ToEvent(TxEntity transaction) => new(transaction.Id, transaction.Type.ToString(), transaction.InvestmentAccountId, transaction.ClassId, transaction.TargetClassId, 10m, 10m);

    private sealed class TestExecutionContextAccessor : IExecutionContextAccessor, IExecutionContextScopeFactory
    {
        private ExecutionContextSnapshot? _current;
        public bool HasCurrent => _current is not null;
        public ExecutionContextSnapshot Current => _current ?? throw new InvalidOperationException();

        public static TestExecutionContextAccessor ForTenant(Guid tenantId) => new()
        {
            _current = ExecutionContextSnapshot.ForTenant(Guid.NewGuid(), Guid.NewGuid(), null, tenantId, "service", "plan02-test", "ifx-tests", "reliable-events", 1)
        };

        public IDisposable Push(ExecutionContextSnapshot context)
        {
            var previous = _current;
            _current = context;
            return new ActionOnDispose(() => _current = previous);
        }

        public async Task RunAsync(ExecutionContextSnapshot context, Func<CancellationToken, Task> operation, CancellationToken cancellationToken = default)
        {
            using var scope = Push(context);
            await operation(cancellationToken);
        }

        public Task RunDetachedAsync(Func<CancellationToken, Task> operation, CancellationToken cancellationToken = default) => operation(cancellationToken);
    }

    private sealed class ActionOnDispose(Action action) : IDisposable
    {
        public void Dispose() => action();
    }
}
