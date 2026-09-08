using System.Text.Json;
using IFX.ApiHost.Runtime;
using IFX.BuildingBlocks.Application.Context;
using IFX.Modules.Holdings.Application.Integrations;
using IFX.Modules.Holdings.Infrastructure.Integrations;
using IFX.Modules.Holdings.Infrastructure.Persistence;
using IFX.Modules.Transaction.Contracts.V1.Events;
using IFX.Platform.Messaging.Contracts.Messaging;
using IFX.Platform.Messaging.Runtime;
using MediatR;
using Microsoft.EntityFrameworkCore;
using Moq;

namespace IFX.IntegrationTests.Runtime;

public sealed class HoldingsInboundContextTests
{
    [Fact]
    public async Task Adapter_scopes_event_identity_and_downstream_causation_then_restores_parent()
    {
        var accessor = new ExecutionContextAccessor();
        var parent = ExecutionContextSnapshot.ForTenant(
            Guid.NewGuid(), Guid.NewGuid(), null, Guid.NewGuid(), "service", "test", "ifx-tests", "parent", 1);
        var message = LogicalMessage(parent.TenantId!.Value);
        ExecutionContextSnapshot? observed = null;
        OutboxLogicalMessage? downstream = null;
        var sender = new Mock<ISender>();
        sender.Setup(item => item.Send(It.IsAny<ApplyTransactionProcessedCommand>(), It.IsAny<CancellationToken>()))
            .Returns<ApplyTransactionProcessedCommand, CancellationToken>((_, _) =>
            {
                observed = accessor.Current;
                downstream = new OutboxMessageFactory(accessor).Create(
                    new { State = "updated" }, "ifx.holdings", "ifx.holdings.projection-updated.v1", 1, message.Envelope.TenantId!.Value);
                return Task.FromResult(InboxCommandResult.Applied());
            });
        await using var dbContext = CreateDbContext();
        var handler = new HoldingsInboundIntegrationEventHandler(sender.Object, dbContext, accessor);

        using (accessor.Push(parent))
        {
            await handler.HandleAsync(message, CancellationToken.None);
            accessor.Current.Should().BeSameAs(parent);
        }

        observed!.OperationId.Value.Should().Be(message.Envelope.EventId);
        observed.CorrelationId.Value.Should().Be(message.Envelope.CorrelationId);
        observed.CausationId!.Value.Value.Should().Be(message.Envelope.CausationId);
        downstream!.Envelope.CorrelationId.Should().Be(message.Envelope.CorrelationId);
        downstream.Envelope.CausationId.Should().Be(message.Envelope.EventId);
        accessor.HasCurrent.Should().BeFalse();
    }

    [Fact]
    public async Task Adapter_restores_parent_context_when_application_handler_crashes()
    {
        var accessor = new ExecutionContextAccessor();
        var parent = ExecutionContextSnapshot.ForTenant(
            Guid.NewGuid(), Guid.NewGuid(), null, Guid.NewGuid(), "service", "test", "ifx-tests", "parent", 1);
        var sender = new Mock<ISender>();
        sender.Setup(item => item.Send(It.IsAny<ApplyTransactionProcessedCommand>(), It.IsAny<CancellationToken>()))
            .ThrowsAsync(new TimeoutException("handler crash"));
        await using var dbContext = CreateDbContext();
        var handler = new HoldingsInboundIntegrationEventHandler(sender.Object, dbContext, accessor);

        using (accessor.Push(parent))
        {
            Func<Task> act = () => handler.HandleAsync(LogicalMessage(parent.TenantId!.Value), CancellationToken.None);
            await act.Should().ThrowAsync<TimeoutException>();
            accessor.Current.Should().BeSameAs(parent);
        }

        accessor.HasCurrent.Should().BeFalse();
    }

    private static HoldingsDbContext CreateDbContext() => new(
        new DbContextOptionsBuilder<HoldingsDbContext>()
            .UseInMemoryDatabase($"inbound-context-{Guid.NewGuid():N}")
            .Options);

    private static OutboxLogicalMessage LogicalMessage(Guid tenantId)
    {
        var payload = new TransactionProcessedV1(Guid.NewGuid(), "Subscription", Guid.NewGuid(), Guid.NewGuid(), null, 10m, 2m);
        return new OutboxLogicalMessage(
            new EventEnvelope(
                Guid.NewGuid(), TransactionProcessedV1.EventType, 1, DateTimeOffset.UtcNow,
                "ifx.transaction", EventEnvelope.TenantScope, tenantId, Guid.NewGuid(), Guid.NewGuid()),
            JsonSerializer.Serialize(payload, new JsonSerializerOptions(JsonSerializerDefaults.Web)));
    }
}
