using System.Diagnostics;
using IFX.Modules.Transaction.Contracts.V1.Events;
using IFX.Platform.Messaging.Contracts.Messaging;
using IFX.Platform.Messaging.Runtime;
using Microsoft.Extensions.DependencyInjection;

namespace IFX.IntegrationTests.Runtime;

public sealed class InboundIntegrationEventTransportAdapterTests
{
    private const string TraceParent = "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01";

    [Theory]
    [InlineData(IntegrationEventTransportHeaders.TraceParent, "damaged-trace")]
    [InlineData(IntegrationEventTransportHeaders.TraceState, "invalid\nstate")]
    public async Task Invalid_trace_is_restarted_and_sanitized_before_the_real_handler(
        string header,
        string value)
    {
        var logical = LogicalMessage();
        var raw = WithHeader(
            IntegrationEventTransportCodec.Encode(logical),
            header,
            value);
        var handler = new RecordingInboundHandler();
        using var provider = CreateProvider(handler);
        Activity? stopped = null;
        using var listener = Listen(activity => stopped = activity);

        var result = await provider.GetRequiredService<IInboundIntegrationEventReceiver>()
            .ReceiveAsync(raw, CancellationToken.None);

        result.Disposition.Should().Be(InboundIntegrationEventDisposition.Accepted);
        result.ReasonCode.Should().Be("G05-EVENT-TRACE-RESTARTED");
        result.TraceRestarted.Should().BeTrue();
        handler.Messages.Should().ContainSingle();
        handler.Messages[0].Envelope.TraceParent.Should().BeNull();
        handler.Messages[0].Envelope.TraceState.Should().BeNull();
        handler.Messages[0].Envelope.EventId.Should().Be(logical.Envelope.EventId);
        handler.Messages[0].Envelope.CorrelationId.Should().Be(logical.Envelope.CorrelationId);
        handler.Messages[0].Envelope.CausationId.Should().Be(logical.Envelope.CausationId);
        handler.Messages[0].Envelope.TenantId.Should().Be(logical.Envelope.TenantId);
        stopped.Should().NotBeNull();
        stopped!.ParentSpanId.Should().Be(default(ActivitySpanId));
        stopped.TraceId.Should().NotBe(default(ActivityTraceId));
        stopped.GetTagItem("ifx.trace.restarted").Should().Be(true);
        handler.ObservedActivityContext.Should().NotBeNull();
        handler.ObservedActivityContext!.Value.TraceId.Should().Be(stopped.TraceId);
    }

    [Fact]
    public async Task Valid_remote_trace_is_continued_without_changing_the_envelope()
    {
        var logical = LogicalMessage();
        var raw = IntegrationEventTransportCodec.Encode(logical);
        var handler = new RecordingInboundHandler();
        using var provider = CreateProvider(handler);
        Activity? stopped = null;
        using var listener = Listen(activity => stopped = activity);
        ActivityContext.TryParse(TraceParent, "vendor=value", true, out var remote).Should().BeTrue();

        var result = await provider.GetRequiredService<IInboundIntegrationEventReceiver>()
            .ReceiveAsync(raw, CancellationToken.None);

        result.Disposition.Should().Be(InboundIntegrationEventDisposition.Accepted);
        result.TraceRestarted.Should().BeFalse();
        handler.Messages.Should().ContainSingle();
        handler.Messages[0].Envelope.TraceParent.Should().Be(TraceParent);
        handler.Messages[0].Envelope.TraceState.Should().Be("vendor=value");
        stopped.Should().NotBeNull();
        stopped!.ParentSpanId.Should().Be(remote.SpanId);
        stopped.GetTagItem("ifx.trace.restarted").Should().Be(false);
        handler.ObservedActivityContext.Should().NotBeNull();
        handler.ObservedActivityContext!.Value.TraceId.Should().Be(remote.TraceId);
    }

    [Theory]
    [InlineData(IntegrationEventTransportHeaders.EventId, "not-a-guid", "G05-EVENT-CONTEXT-INVALID")]
    [InlineData(IntegrationEventTransportHeaders.SchemaVersion, "2", "G05-EVENT-CONTEXT-INVALID")]
    [InlineData(IntegrationEventTransportHeaders.Producer, "UNTRUSTED", "G05-EVENT-CONTEXT-INVALID")]
    [InlineData(IntegrationEventTransportHeaders.TenantId, "not-a-guid", "G05-EVENT-TENANT-INVALID")]
    public async Task Invalid_business_context_is_quarantined_before_handler_dispatch(
        string header,
        string value,
        string reasonCode)
    {
        var raw = WithHeader(IntegrationEventTransportCodec.Encode(LogicalMessage()), header, value);
        var handler = new RecordingInboundHandler();
        using var provider = CreateProvider(handler);

        var result = await provider.GetRequiredService<IInboundIntegrationEventReceiver>()
            .ReceiveAsync(raw, CancellationToken.None);

        result.Disposition.Should().Be(InboundIntegrationEventDisposition.Quarantined);
        result.ReasonCode.Should().Be(reasonCode);
        result.TraceRestarted.Should().BeFalse();
        handler.Messages.Should().BeEmpty();
    }

    [Fact]
    public async Task In_process_sender_uses_the_raw_transport_boundary()
    {
        var logical = LogicalMessage();
        var handler = new RecordingInboundHandler();
        using var provider = CreateProvider(handler);

        await provider.GetRequiredService<IIntegrationEventSender>()
            .SendAsync(logical, CancellationToken.None);

        handler.Messages.Should().ContainSingle().Which.Should().BeEquivalentTo(logical);
    }

    private static ServiceProvider CreateProvider(RecordingInboundHandler handler)
    {
        var services = new ServiceCollection();
        services.AddSingleton(handler);
        services.AddScoped<IInboundIntegrationEventHandler>(provider =>
            provider.GetRequiredService<RecordingInboundHandler>());
        services.AddMessagingRuntime();
        return services.BuildServiceProvider();
    }

    private static ActivityListener Listen(Action<Activity> stopped)
    {
        var listener = new ActivityListener
        {
            ShouldListenTo = source => source.Name == RawIntegrationEventReceiver.ActivitySourceName,
            Sample = static (ref ActivityCreationOptions<ActivityContext> _) => ActivitySamplingResult.AllDataAndRecorded,
            ActivityStopped = stopped
        };
        ActivitySource.AddActivityListener(listener);
        return listener;
    }

    private static InboundIntegrationEventMessage WithHeader(
        InboundIntegrationEventMessage message,
        string header,
        string value)
    {
        var headers = new Dictionary<string, string>(message.Headers, StringComparer.OrdinalIgnoreCase)
        {
            [header] = value
        };
        return message with { Headers = headers };
    }

    private static OutboxLogicalMessage LogicalMessage()
    {
        var payload = "{\"transactionId\":\"tx-1\"}";
        return new OutboxLogicalMessage(
            new EventEnvelope(
                Guid.NewGuid(),
                TransactionProcessedV1.EventType,
                1,
                DateTimeOffset.UtcNow,
                "ifx.transaction",
                EventEnvelope.TenantScope,
                Guid.NewGuid(),
                Guid.NewGuid(),
                Guid.NewGuid(),
                traceParent: TraceParent,
                traceState: "vendor=value"),
            payload);
    }

    private sealed class RecordingInboundHandler : IInboundIntegrationEventHandler
    {
        public List<OutboxLogicalMessage> Messages { get; } = [];
        public ActivityContext? ObservedActivityContext { get; private set; }

        public bool CanHandle(string eventType, int schemaVersion) =>
            eventType == TransactionProcessedV1.EventType && schemaVersion == 1;

        public Task HandleAsync(OutboxLogicalMessage message, CancellationToken cancellationToken)
        {
            ObservedActivityContext = Activity.Current?.Context;
            Messages.Add(message);
            return Task.CompletedTask;
        }
    }
}
