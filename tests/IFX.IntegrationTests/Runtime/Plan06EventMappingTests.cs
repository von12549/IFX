using System.Text.Json;
using IFX.BuildingBlocks.Application.Context;
using IFX.Modules.Registry.Application.Events;
using IFX.Modules.Registry.Contracts.V1.Events;
using IFX.Modules.Registry.Infrastructure.Messaging;
using IFX.Modules.Registry.Infrastructure.Persistence;
using IFX.Modules.Transaction.Application.Events;
using IFX.Modules.Transaction.Contracts.V1.Events;
using IFX.Modules.Transaction.Infrastructure.Messaging;
using IFX.Modules.Transaction.Infrastructure.Persistence;
using IFX.Platform.Messaging.Runtime;
using Microsoft.EntityFrameworkCore;
using Moq;

namespace IFX.IntegrationTests.Runtime;

public sealed class Plan06EventMappingTests
{
    private static readonly JsonSerializerOptions Web = new(JsonSerializerDefaults.Web);

    [Fact]
    public void Registry_internal_fact_preserves_existing_v1_payload()
    {
        var fact = new ClassStatusChanged(Guid.NewGuid(), Guid.NewGuid(), "Active", "Closed");
        var expected = new ClassStatusChangedV1(fact.ClassId, fact.FundId, fact.OldStatus, fact.NewStatus);

        JsonSerializer.Serialize(ClassStatusChangedV1Mapper.Map(fact), Web)
            .Should().Be(JsonSerializer.Serialize(expected, Web));
    }

    [Fact]
    public void Transaction_internal_fact_preserves_existing_v1_payload()
    {
        var fact = new TransactionProcessed(Guid.NewGuid(), "Subscription", Guid.NewGuid(), Guid.NewGuid(), null, 12.5m, 3.25m);
        var expected = new TransactionProcessedV1(fact.TransactionId, fact.TransactionType,
            fact.InvestmentAccountId, fact.ClassId, fact.TargetClassId, fact.Units, fact.NavPrice);

        JsonSerializer.Serialize(TransactionProcessedV1Mapper.Map(fact), Web)
            .Should().Be(JsonSerializer.Serialize(expected, Web));
    }

    [Fact]
    public async Task Registry_outbox_rejects_unregistered_fact_before_persistence()
    {
        await using var context = new RegistryDbContext(new DbContextOptionsBuilder<RegistryDbContext>()
            .UseInMemoryDatabase(Guid.NewGuid().ToString()).Options);
        var source = new BufferedIntegrationEventSource();
        source.Add(new object());
        var execution = TrustedExecution();
        var participant = new RegistryOutboxParticipant(context, source, new OutboxMessageFactory(execution), execution);

        await Assert.ThrowsAsync<InvalidOperationException>(() =>
            participant.PrepareAsync(new object(), null, CancellationToken.None));

        context.OutboxMessages.Local.Should().BeEmpty();
    }

    [Fact]
    public async Task Transaction_outbox_rejects_unregistered_fact_before_persistence()
    {
        await using var context = new TransactionDbContext(new DbContextOptionsBuilder<TransactionDbContext>()
            .UseInMemoryDatabase(Guid.NewGuid().ToString()).Options);
        var source = new BufferedIntegrationEventSource();
        source.Add(new object());
        var execution = TrustedExecution();
        var participant = new TransactionOutboxParticipant(context, source, new OutboxMessageFactory(execution), execution);

        await Assert.ThrowsAsync<InvalidOperationException>(() =>
            participant.PrepareAsync(new object(), null, CancellationToken.None));

        context.OutboxMessages.Local.Should().BeEmpty();
    }

    private static IExecutionContextAccessor TrustedExecution()
    {
        var current = ExecutionContextSnapshot.ForTenant(Guid.NewGuid(), Guid.NewGuid(), null,
            Guid.NewGuid(), "service", "plan06-test", "ifx-tests", "event-mapping", 1);
        var execution = new Mock<IExecutionContextAccessor>();
        execution.SetupGet(value => value.HasCurrent).Returns(true);
        execution.SetupGet(value => value.Current).Returns(current);
        return execution.Object;
    }
}
