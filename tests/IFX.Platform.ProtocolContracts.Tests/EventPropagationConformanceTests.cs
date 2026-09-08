using System.Diagnostics;
using System.Globalization;
using System.Text.Json;
using IFX.BuildingBlocks.Application.Context;
using IFX.Platform.Context.Contracts;
using IFX.Platform.Messaging.Contracts.Messaging;

namespace IFX.Platform.ProtocolContracts.Tests;

public sealed class EventPropagationConformanceTests
{
    private static readonly JsonSerializerOptions JsonOptions = new(JsonSerializerDefaults.Web);
    private static readonly Guid TenantId = Guid.Parse("22222222-2222-4222-8222-222222222222");
    private static readonly Guid CorrelationId = Guid.Parse("33333333-3333-4333-8333-333333333333");
    private static readonly Guid OperationId = Guid.Parse("44444444-4444-4444-8444-444444444444");
    private static readonly DateTimeOffset OccurredAt = DateTimeOffset.Parse(
        "2026-09-08T00:00:00+00:00", CultureInfo.InvariantCulture);
    private const string TraceParent = "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01";

    [Fact]
    public void GoldenFixture_SatisfiesSchemaAndRoundTrips()
    {
        using var schema = JsonDocument.Parse(ReadRepositoryFile("docs/architecture/review/gates/G05/schemas/event-envelope-v1.schema.json"));
        using var fixture = JsonDocument.Parse(ReadRepositoryFile("docs/architecture/review/gates/G05/fixtures/event-envelope-v1.golden.json"));
        var required = schema.RootElement.GetProperty("required").EnumerateArray()
            .Select(item => item.GetString()!)
            .ToArray();

        required.All(name => fixture.RootElement.TryGetProperty(name, out _)).Should().BeTrue();
        schema.RootElement.GetProperty("additionalProperties").GetBoolean().Should().BeTrue();

        var envelope = JsonSerializer.Deserialize<EventEnvelope>(fixture.RootElement.GetRawText(), JsonOptions);
        envelope.Should().NotBeNull();
        envelope!.EventType.Should().Be("ifx.transaction.transaction-processed.v1");
        envelope.OccurredAt.Offset.Should().Be(TimeSpan.Zero);
        envelope.EnvelopeVersion.Should().Be(1);
    }

    [Fact]
    public void EnvelopeDeserializer_IgnoresUnknownFieldsAfterRequiredValidation()
    {
        var json = ReadRepositoryFile("docs/architecture/review/gates/G05/fixtures/event-envelope-v1.golden.json")
            .TrimEnd()
            .TrimEnd('}') + ",\"futureField\":{\"value\":1}}";

        var envelope = JsonSerializer.Deserialize<EventEnvelope>(json, JsonOptions);

        envelope.Should().NotBeNull();
        envelope!.EventId.Should().Be(Guid.Parse("11111111-1111-4111-8111-111111111111"));
    }

    [Fact]
    public void Producer_CapturesTrustedExecutionAndRuntimeIdentityOnce()
    {
        var execution = CreateExecutionContext();
        var producer = new ConformanceEventProducer("ifx.transaction", () => OccurredAt);

        var message = producer.Create(
            execution,
            "ifx.transaction.transaction-processed.v1",
            1,
            "{\"producer\":\"payload-impostor\"}",
            TraceParent,
            "vendor=value");

        message.Envelope.EventId.Should().NotBe(Guid.Empty);
        message.Envelope.OccurredAt.Should().Be(OccurredAt);
        message.Envelope.Producer.Should().Be("ifx.transaction");
        message.Envelope.CorrelationId.Should().Be(CorrelationId);
        message.Envelope.CausationId.Should().Be(OperationId);
        message.Envelope.TenantId.Should().Be(TenantId);
        message.Payload.Should().Contain("payload-impostor");
    }

    [Fact]
    public void Outbox_SeparatesImmutableLogicalMessageFromMutableDeliveryMetadata()
    {
        var record = CreateOutboxRecord();
        var envelopeBefore = JsonSerializer.Serialize(record.Logical.Envelope, JsonOptions);
        var payloadBefore = record.Logical.Payload;

        record.Delivery.AttemptCount++;
        record.Delivery.Lease = "worker-2";
        record.Delivery.NextAttemptAt = OccurredAt.AddMinutes(1);
        record.Delivery.LastErrorCode = "transport_timeout";

        JsonSerializer.Serialize(record.Logical.Envelope, JsonOptions).Should().Be(envelopeBefore);
        record.Logical.Payload.Should().Be(payloadBefore);
    }

    [Fact]
    public void Dispatcher_MapsFrozenEnvelopeAndDoesNotReadProducerFromPayload()
    {
        var record = CreateOutboxRecord("{\"producer\":\"payload-impostor\"}");
        var carrier = new RecordingEventCarrier();

        FakeEventDispatcher.Dispatch(record, carrier);

        var sent = carrier.Messages.Should().ContainSingle().Subject;
        sent.Headers[EventHeaders.Producer].Should().Be("ifx.transaction");
        sent.Headers[EventHeaders.EventId].Should().Be(record.Logical.Envelope.EventId.ToString("D"));
        sent.Payload.Should().Contain("payload-impostor");
    }

    [Fact]
    public void RetryAndReplay_PreserveLogicalEnvelopeAndPayload()
    {
        var record = CreateOutboxRecord();
        var carrier = new RecordingEventCarrier();

        FakeEventDispatcher.Dispatch(record, carrier);
        record.Delivery.LastErrorCode = "transport_timeout";
        FakeEventDispatcher.Dispatch(record, carrier);
        FakeEventDispatcher.Dispatch(record, carrier, isReplay: true);

        carrier.Messages.Should().HaveCount(3);
        carrier.Messages.Select(message => SerializeLogical(message)).Distinct().Should().ContainSingle();
        record.Delivery.AttemptCount.Should().Be(3);
    }

    [Fact]
    public void Consumer_UsesEventIdentityForExecutionAndDownstreamCausation()
    {
        var record = CreateOutboxRecord();
        var carrier = new RecordingEventCarrier();
        FakeEventDispatcher.Dispatch(record, carrier);
        var inbox = new FakeInboundEventAdapter(new HashSet<string> { "ifx.transaction" });

        var result = inbox.Handle("holdings-projection", carrier.Messages.Single());
        var downstream = new ConformanceEventProducer("ifx.holdings", () => OccurredAt.AddSeconds(1))
            .Create(result.ExecutionContext!, "ifx.holdings.position-updated.v1", 1, "{}", null, null);

        result.Status.Should().Be(EventHandlingStatus.Applied);
        result.ExecutionContext!.OperationId.Value.Should().Be(record.Logical.Envelope.EventId);
        result.ExecutionContext.CorrelationId.Value.Should().Be(record.Logical.Envelope.CorrelationId);
        result.ExecutionContext.CausationId!.Value.Value.Should().Be(record.Logical.Envelope.EventId);
        downstream.Envelope.CorrelationId.Should().Be(record.Logical.Envelope.CorrelationId);
        downstream.Envelope.CausationId.Should().Be(record.Logical.Envelope.EventId);
    }

    [Fact]
    public void Inbox_DeduplicatesByConsumerAndEventId()
    {
        var record = CreateOutboxRecord();
        var carrier = new RecordingEventCarrier();
        FakeEventDispatcher.Dispatch(record, carrier);
        var inbox = new FakeInboundEventAdapter(new HashSet<string> { "ifx.transaction" });

        var first = inbox.Handle("holdings-projection", carrier.Messages.Single());
        var duplicate = inbox.Handle("holdings-projection", carrier.Messages.Single());

        first.Status.Should().Be(EventHandlingStatus.Applied);
        duplicate.Status.Should().Be(EventHandlingStatus.Duplicate);
        inbox.AcceptedCount.Should().Be(1);
    }

    [Fact]
    public void InvalidTrace_RestartsTraceWithoutRejectingBusinessEvent()
    {
        var message = CreateTransportMessage();
        message.Headers[EventHeaders.TraceParent] = "damaged-trace";
        var inbox = new FakeInboundEventAdapter(new HashSet<string> { "ifx.transaction" });

        var result = inbox.Handle("holdings-projection", message);

        result.Status.Should().Be(EventHandlingStatus.Applied);
        result.TraceRestarted.Should().BeTrue();
    }

    [Theory]
    [InlineData("not-a-guid")]
    [InlineData("00000000-0000-0000-0000-000000000000")]
    public void InvalidTenant_IsQuarantinedBeforeInboxOrApplication(string tenant)
    {
        var message = CreateTransportMessage();
        message.Headers[EventHeaders.TenantId] = tenant;
        var inbox = new FakeInboundEventAdapter(new HashSet<string> { "ifx.transaction" });

        var result = inbox.Handle("holdings-projection", message);

        result.Status.Should().Be(EventHandlingStatus.Quarantined);
        result.Code.Should().Be("event_tenant_invalid");
        inbox.AcceptedCount.Should().Be(0);
    }

    [Fact]
    public void UnregisteredProducer_IsQuarantinedBeforeOtherValidation()
    {
        var message = CreateTransportMessage();
        message.Headers[EventHeaders.Producer] = "ifx.unknown";
        message.Headers[EventHeaders.TenantId] = "damaged";
        var inbox = new FakeInboundEventAdapter(new HashSet<string> { "ifx.transaction" });

        var result = inbox.Handle("holdings-projection", message);

        result.Code.Should().Be("event_producer_denied");
        result.ValidationTrace.Should().Equal("producerAllowlist");
    }

    private static ExecutionContextSnapshot CreateExecutionContext() => new(
        new CorrelationId(CorrelationId),
        new OperationId(OperationId),
        null,
        ExecutionScope.ForTenant(new TenantScope(TenantId)),
        new ActorReference(ActorKind.User, "actor-1"),
        new SourceReference("ifx", "transaction", 1));

    private static FakeOutboxRecord CreateOutboxRecord(string payload = "{\"transactionId\":\"tx-1\"}")
    {
        var logical = new ConformanceEventProducer("ifx.transaction", () => OccurredAt).Create(
            CreateExecutionContext(),
            "ifx.transaction.transaction-processed.v1",
            1,
            payload,
            TraceParent,
            "vendor=value");
        return new FakeOutboxRecord(logical);
    }

    private static FakeTransportMessage CreateTransportMessage()
    {
        var record = CreateOutboxRecord();
        var carrier = new RecordingEventCarrier();
        FakeEventDispatcher.Dispatch(record, carrier);
        return carrier.Messages.Single();
    }

    private static string SerializeLogical(FakeTransportMessage message) =>
        JsonSerializer.Serialize(new { message.Headers, message.Payload }, JsonOptions);

    private static string ReadRepositoryFile(string path)
    {
        var directory = new DirectoryInfo(AppContext.BaseDirectory);
        while (directory is not null && !File.Exists(Path.Combine(directory.FullName, "IFX.sln")))
        {
            directory = directory.Parent;
        }

        directory.Should().NotBeNull("the tests must run beneath the repository root");
        return File.ReadAllText(Path.Combine(directory!.FullName, path.Replace('/', Path.DirectorySeparatorChar)));
    }
}

internal sealed record EventLogicalMessage(EventEnvelope Envelope, string Payload);

internal sealed class EventDeliveryMetadata
{
    public int AttemptCount { get; set; }
    public string? Lease { get; set; }
    public DateTimeOffset? NextAttemptAt { get; set; }
    public string? LastErrorCode { get; set; }
}

internal sealed class FakeOutboxRecord(EventLogicalMessage logical)
{
    public EventLogicalMessage Logical { get; } = logical;
    public EventDeliveryMetadata Delivery { get; } = new();
}

internal sealed class ConformanceEventProducer(string trustedProducer, Func<DateTimeOffset> utcNow)
{
    public EventLogicalMessage Create(
        ExecutionContextSnapshot context,
        string eventType,
        int schemaVersion,
        string payload,
        string? traceParent,
        string? traceState)
    {
        var envelope = new EventEnvelope(
            Guid.NewGuid(),
            eventType,
            schemaVersion,
            utcNow(),
            trustedProducer,
            context.IsTenantScope ? EventEnvelope.TenantScope : EventEnvelope.PlatformScope,
            context.TenantId,
            context.CorrelationId.Value,
            context.OperationId.Value,
            traceParent: traceParent,
            traceState: traceState,
            provenance: context.Provenance == ContextProvenance.Trusted
                ? EventEnvelope.TrustedProvenance
                : EventEnvelope.SynthesizedProvenance);
        return new EventLogicalMessage(envelope, payload);
    }
}

internal static class EventHeaders
{
    public const string EnvelopeVersion = "ifx-envelope-version";
    public const string EventId = "ifx-event-id";
    public const string EventType = "ifx-event-type";
    public const string SchemaVersion = "ifx-schema-version";
    public const string OccurredAt = "ifx-occurred-at";
    public const string Producer = "ifx-producer";
    public const string Scope = "ifx-scope";
    public const string TenantId = "ifx-tenant-id";
    public const string CorrelationId = "ifx-correlation-id";
    public const string CausationId = "ifx-causation-id";
    public const string ContentType = "content-type";
    public const string TraceParent = "traceparent";
    public const string TraceState = "tracestate";
    public const string Provenance = "ifx-provenance";
}

internal sealed class FakeTransportMessage(Dictionary<string, string> headers, string payload)
{
    public Dictionary<string, string> Headers { get; } = headers;
    public string Payload { get; } = payload;
}

internal interface IFakeEventCarrier
{
    void Send(FakeTransportMessage message);
}

internal sealed class RecordingEventCarrier : IFakeEventCarrier
{
    public List<FakeTransportMessage> Messages { get; } = [];
    public void Send(FakeTransportMessage message) => Messages.Add(message);
}

internal static class FakeEventDispatcher
{
    public static void Dispatch(FakeOutboxRecord record, IFakeEventCarrier carrier, bool isReplay = false)
    {
        var envelope = record.Logical.Envelope;
        var headers = new Dictionary<string, string>(StringComparer.Ordinal)
        {
            [EventHeaders.EnvelopeVersion] = envelope.EnvelopeVersion.ToString(CultureInfo.InvariantCulture),
            [EventHeaders.EventId] = envelope.EventId.ToString("D"),
            [EventHeaders.EventType] = envelope.EventType,
            [EventHeaders.SchemaVersion] = envelope.SchemaVersion.ToString(CultureInfo.InvariantCulture),
            [EventHeaders.OccurredAt] = envelope.OccurredAt.ToString("O", CultureInfo.InvariantCulture),
            [EventHeaders.Producer] = envelope.Producer,
            [EventHeaders.Scope] = envelope.Scope,
            [EventHeaders.CorrelationId] = envelope.CorrelationId.ToString("D"),
            [EventHeaders.CausationId] = envelope.CausationId.ToString("D"),
            [EventHeaders.ContentType] = envelope.ContentType,
            [EventHeaders.Provenance] = envelope.Provenance
        };

        if (envelope.TenantId is { } tenantId) headers[EventHeaders.TenantId] = tenantId.ToString("D");
        if (envelope.TraceParent is { } traceParent) headers[EventHeaders.TraceParent] = traceParent;
        if (envelope.TraceState is { } traceState) headers[EventHeaders.TraceState] = traceState;

        record.Delivery.AttemptCount++;
        record.Delivery.Lease = isReplay ? "replay-worker" : "dispatcher-worker";
        carrier.Send(new FakeTransportMessage(headers, record.Logical.Payload));
    }
}

internal enum EventHandlingStatus
{
    Applied,
    Duplicate,
    Quarantined
}

internal sealed record EventHandlingResult(
    EventHandlingStatus Status,
    string Code,
    bool TraceRestarted,
    ExecutionContextSnapshot? ExecutionContext,
    IReadOnlyList<string> ValidationTrace);

internal sealed class FakeInboundEventAdapter(IReadOnlySet<string> allowedProducers)
{
    private readonly HashSet<(string Consumer, Guid EventId)> _inbox = [];

    public int AcceptedCount => _inbox.Count;

    public EventHandlingResult Handle(string consumerId, FakeTransportMessage message)
    {
        var trace = new List<string>();
        trace.Add("producerAllowlist");
        if (!message.Headers.TryGetValue(EventHeaders.Producer, out var producer) || !allowedProducers.Contains(producer))
        {
            return Quarantine("event_producer_denied", trace);
        }

        trace.Add("envelopeAndSchemaVersion");
        if (!TryInt(message, EventHeaders.EnvelopeVersion, out var envelopeVersion) || envelopeVersion != 1 ||
            !TryInt(message, EventHeaders.SchemaVersion, out var schemaVersion) || schemaVersion <= 0 ||
            !message.Headers.TryGetValue(EventHeaders.OccurredAt, out var occurredAtText) ||
            !DateTimeOffset.TryParseExact(occurredAtText, "O", CultureInfo.InvariantCulture, DateTimeStyles.None, out var occurredAt) ||
            occurredAt.Offset != TimeSpan.Zero ||
            !message.Headers.TryGetValue(EventHeaders.Provenance, out var provenance) ||
            provenance is not (EventEnvelope.TrustedProvenance or EventEnvelope.SynthesizedProvenance))
        {
            return Quarantine("event_context_invalid", trace);
        }

        trace.Add("eventIdentity");
        if (!TryGuid(message, EventHeaders.EventId, out var eventId) ||
            !message.Headers.TryGetValue(EventHeaders.EventType, out var eventType) ||
            !eventType.EndsWith($".v{schemaVersion}", StringComparison.Ordinal))
        {
            return Quarantine("event_context_invalid", trace);
        }

        trace.Add("scopeAndTenant");
        if (!message.Headers.TryGetValue(EventHeaders.Scope, out var scope) || scope != EventEnvelope.TenantScope ||
            !TryGuid(message, EventHeaders.TenantId, out var tenantId))
        {
            return Quarantine("event_tenant_invalid", trace);
        }

        trace.Add("correlationAndCausation");
        if (!TryGuid(message, EventHeaders.CorrelationId, out var correlationId) ||
            !TryGuid(message, EventHeaders.CausationId, out _))
        {
            return Quarantine("event_context_invalid", trace);
        }

        trace.Add("contentType");
        if (!message.Headers.TryGetValue(EventHeaders.ContentType, out var contentType) ||
            contentType != EventEnvelope.JsonContentType)
        {
            return Quarantine("event_context_invalid", trace);
        }

        trace.Add("trace");
        var traceRestarted = message.Headers.TryGetValue(EventHeaders.TraceParent, out var traceParent) &&
            !ActivityContext.TryParse(
                traceParent,
                message.Headers.GetValueOrDefault(EventHeaders.TraceState),
                true,
                out _);

        if (!_inbox.Add((consumerId, eventId)))
        {
            return new EventHandlingResult(EventHandlingStatus.Duplicate, "event_duplicate", traceRestarted, null, trace);
        }

        var sourceParts = producer.Split('.', 2);
        var execution = new ExecutionContextSnapshot(
            new CorrelationId(correlationId),
            new OperationId(eventId),
            new CausationId(eventId),
            ExecutionScope.ForTenant(new TenantScope(tenantId)),
            new ActorReference(ActorKind.System, producer),
            new SourceReference(sourceParts[0], sourceParts[1], schemaVersion));

        return new EventHandlingResult(EventHandlingStatus.Applied, "success", traceRestarted, execution, trace);
    }

    private static EventHandlingResult Quarantine(string code, IReadOnlyList<string> trace) =>
        new(EventHandlingStatus.Quarantined, code, false, null, trace);

    private static bool TryGuid(FakeTransportMessage message, string header, out Guid value)
    {
        value = default;
        return message.Headers.TryGetValue(header, out var text) &&
            Guid.TryParseExact(text, "D", out value) && value != Guid.Empty;
    }

    private static bool TryInt(FakeTransportMessage message, string header, out int value)
    {
        value = default;
        return message.Headers.TryGetValue(header, out var text) &&
            int.TryParse(text, NumberStyles.None, CultureInfo.InvariantCulture, out value);
    }
}
