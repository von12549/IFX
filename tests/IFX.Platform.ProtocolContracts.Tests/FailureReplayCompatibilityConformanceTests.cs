using System.Globalization;
using System.Text;
using System.Text.Json;
using System.Text.RegularExpressions;
using IFX.Platform.Messaging.Contracts.Messaging;

namespace IFX.Platform.ProtocolContracts.Tests;

public sealed class FailureReplayCompatibilityConformanceTests
{
    private static readonly DateTimeOffset Now = DateTimeOffset.Parse(
        "2026-09-08T02:00:00+00:00", CultureInfo.InvariantCulture);
    private static readonly Guid TenantId = Guid.Parse("22222222-2222-4222-8222-222222222222");

    [Fact]
    public void Policy_DefinesAllFailureClassesAndFixedPreInboxOrder()
    {
        using var document = JsonDocument.Parse(ReadRepositoryFile(
            "docs/architecture/review/gates/G05/failure-replay-compatibility-v1.json"));
        var root = document.RootElement;

        root.GetProperty("status").GetString().Should().Be("pre-active-fake-carrier-conformance");
        root.GetProperty("failureMatrix").EnumerateArray()
            .Select(item => item.GetProperty("class").GetString())
            .Should().Equal("Diagnostic", "Client", "Business", "Transient", "Permanent", "Security");
        root.GetProperty("preInboxValidation").GetProperty("order").EnumerateArray()
            .Select(item => item.GetString())
            .Should().Equal("eventType", "eventVersion", "eventId", "producer", "tenant", "correlation", "causation");
        root.GetProperty("realDurabilityEvidence").GetString().Should().Contain("required from Plan 02");
    }

    [Theory]
    [InlineData(G05FailureClass.Diagnostic, false, G05FailureAction.Continue)]
    [InlineData(G05FailureClass.Client, false, G05FailureAction.Reject)]
    [InlineData(G05FailureClass.Business, false, G05FailureAction.Complete)]
    [InlineData(G05FailureClass.Transient, true, G05FailureAction.Retry)]
    [InlineData(G05FailureClass.Permanent, false, G05FailureAction.Quarantine)]
    [InlineData(G05FailureClass.Security, false, G05FailureAction.QuarantineAuditAlert)]
    public void FailureMatrix_HasBoundedDisposition(
        G05FailureClass failureClass,
        bool retry,
        G05FailureAction action)
    {
        var disposition = G05FailureMatrix.Resolve(failureClass);

        disposition.Retry.Should().Be(retry);
        disposition.Action.Should().Be(action);
    }

    [Theory]
    [MemberData(nameof(InvalidCoreEvents))]
    public void CoreEnvelopeFailures_AreStableAndOccurBeforeInbox(
        RawInboundEvent message,
        string expectedCode,
        G05FailureClass expectedClass,
        string expectedLastStep)
    {
        var inbox = new G05FakeInbox();
        var validator = new G05PreInboxValidator(new HashSet<string> { "ifx.transaction" });

        var result = validator.ValidateThenAccept("holdings-projection", message, inbox);

        result.Accepted.Should().BeFalse();
        result.Code.Should().Be(expectedCode);
        result.FailureClass.Should().Be(expectedClass);
        result.ValidationTrace.Should().EndWith(expectedLastStep);
        inbox.WriteCount.Should().Be(0);
    }

    [Fact]
    public void ValidationOrder_IsFailFastAndCannotHideProducerDenialBehindTenantDamage()
    {
        var message = ValidRawEvent() with { Producer = "ifx.untrusted", TenantId = "damaged" };
        var validator = new G05PreInboxValidator(new HashSet<string> { "ifx.transaction" });

        var result = validator.ValidateThenAccept("holdings-projection", message, new G05FakeInbox());

        result.Code.Should().Be("event_producer_denied");
        result.ValidationTrace.Should().Equal("eventType", "eventVersion", "eventId", "producer");
    }

    [Fact]
    public void InvalidTrace_IsDiagnosticAndRestartsWithoutRejectingTheEvent()
    {
        var validator = new G05PreInboxValidator(new HashSet<string> { "ifx.transaction" });
        var inbox = new G05FakeInbox();

        var result = validator.ValidateThenAccept(
            "holdings-projection",
            ValidRawEvent() with { TraceParent = "damaged-trace" },
            inbox);

        result.Accepted.Should().BeTrue();
        result.Code.Should().Be("event_trace_restarted");
        result.FailureClass.Should().Be(G05FailureClass.Diagnostic);
        result.TraceRestarted.Should().BeTrue();
        inbox.WriteCount.Should().Be(1);
    }

    [Theory]
    [InlineData(G05FailureClass.Permanent, false)]
    [InlineData(G05FailureClass.Security, true)]
    public void Quarantine_SeparatesLogicalBytesFromSafeMetadataAndSecurityAudit(
        G05FailureClass failureClass,
        bool expectAudit)
    {
        const string payloadSentinel = "g05-quarantine-payload-sentinel@example.invalid";
        const string exceptionSentinel = "g05 raw provider exception and stack sentinel";
        var envelope = CreateEnvelope();
        var store = new G05FakeQuarantineStore();
        var envelopeBytes = JsonSerializer.SerializeToUtf8Bytes(envelope);
        var payloadBytes = Encoding.UTF8.GetBytes(payloadSentinel);

        var record = store.Capture(
            envelopeBytes,
            payloadBytes,
            failureClass,
            failureClass == G05FailureClass.Security ? "event_tenant_invalid" : "event_version_unsupported",
            "ifx.event-consumer",
            exceptionSentinel,
            Now);

        record.EnvelopeBytes.ToArray().Should().Equal(envelopeBytes);
        record.PayloadBytes.ToArray().Should().Equal(payloadBytes);
        record.SafeMetadata.Keys.Should().BeEquivalentTo(
            "reasonCode", "failureClass", "sourceIdentity", "firstDetectedAt", "lastDetectedAt", "detectionCount", "alertKey");
        string.Join('|', record.SafeMetadata.Values).Should().NotContain(payloadSentinel).And.NotContain(exceptionSentinel);
        store.Alerts.Should().ContainSingle();
        store.SecurityAudits.Should().HaveCount(expectAudit ? 1 : 0);
    }

    [Fact]
    public void TransientRetry_ChangesDeliveryStateOnly()
    {
        var logical = new G05FrozenLogicalMessage(
            JsonSerializer.SerializeToUtf8Bytes(CreateEnvelope()),
            Encoding.UTF8.GetBytes("{\"transactionId\":\"tx-1\"}"));
        var work = new G05DeliveryWork(logical);
        var envelopeBefore = logical.EnvelopeBytes.ToArray();
        var payloadBefore = logical.PayloadBytes.ToArray();

        work.RecordTransientFailure("event_delivery_unavailable", "retry-worker", Now.AddMinutes(1));

        work.Delivery.AttemptCount.Should().Be(1);
        work.Delivery.Lease.Should().Be("retry-worker");
        work.Delivery.LastErrorCode.Should().Be("event_delivery_unavailable");
        logical.EnvelopeBytes.ToArray().Should().Equal(envelopeBefore);
        logical.PayloadBytes.ToArray().Should().Equal(payloadBefore);
    }

    [Fact]
    public void DeadLetterReplay_PreservesEventIdAndCompletedInboxStillDeduplicates()
    {
        var envelope = CreateEnvelope();
        var inbox = new G05FakeInbox();
        var replayer = new G05DeadLetterReplayer();

        inbox.TryComplete("holdings-projection", envelope.EventId).Should().BeTrue();
        var replay = replayer.Replay("holdings-projection", envelope, inbox);

        replay.EventId.Should().Be(envelope.EventId);
        replay.Status.Should().Be("duplicate");
        inbox.WriteCount.Should().Be(1);
    }

    [Fact]
    public void ForcedReprocessing_UsesSeparatelyApprovedRequestAndNeverMutatesEnvelope()
    {
        var envelope = CreateEnvelope();
        var request = G05ReprocessingRequest.Create(
            envelope.EventId,
            "approved_rebuild",
            "actor-hmac-k2-1f3a",
            "change-approval-42",
            Now);

        request.RequestId.Should().NotBe(Guid.Empty).And.NotBe(envelope.EventId);
        request.OriginalEventId.Should().Be(envelope.EventId);
        request.ApprovalReference.Should().Be("change-approval-42");
        envelope.EventId.Should().Be(request.OriginalEventId);

        var action = () => G05ReprocessingRequest.Create(
            envelope.EventId, "approved_rebuild", "actor-hmac-k2-1f3a", "", Now);
        action.Should().Throw<ArgumentException>();
    }

    [Fact]
    public void RegisteredCompatibilityAdapter_SynthesizesOnlyAllowedContextWithProvenanceAndMetric()
    {
        var metrics = new G05BoundedMetricRecorder();
        var registry = G05CompatibilityRegistry.CreateDefault(metrics);
        var legacy = ValidRawEvent() with
        {
            Producer = "ifx.legacy-event-import",
            CorrelationId = "",
            CausationId = ""
        };

        var adapted = registry.Adapt("legacy-event-correlation-v1", legacy, Now);

        adapted.Provenance.Should().Be(EventEnvelope.SynthesizedProvenance);
        adapted.CorrelationId.Should().NotBe(Guid.Empty);
        adapted.CausationId.Should().NotBe(Guid.Empty);
        adapted.EventId.Should().Be(Guid.Parse(legacy.EventId));
        adapted.Producer.Should().Be(legacy.Producer);
        adapted.TenantId.Should().Be(Guid.Parse(legacy.TenantId!));
        metrics.Measurements.Should().ContainSingle(measurement =>
            measurement.Name == "ifx_compatibility_synthesis_total" &&
            measurement.Labels["reason_code"] == "legacy_context_synthesized");
    }

    [Fact]
    public void CompatibilityAdapter_ExpiresFailClosedAndForbiddenIdentitySynthesisCannotRegister()
    {
        var registry = G05CompatibilityRegistry.CreateDefault(new G05BoundedMetricRecorder());

        var expired = () => registry.Adapt(
            "legacy-event-correlation-v1",
            ValidRawEvent() with { Producer = "ifx.legacy-event-import", CorrelationId = "", CausationId = "" },
            DateTimeOffset.Parse("2026-12-01T00:00:00Z", CultureInfo.InvariantCulture));
        expired.Should().Throw<G05CompatibilityException>()
            .Where(exception => exception.Code == "compatibility_adapter_expired");

        var forbidden = () => new G05CompatibilityRegistration(
            "unsafe", "owner", "ifx.legacy-event-import", ["tenantId"], Now.AddDays(1), "reason");
        forbidden.Should().Throw<ArgumentException>();
    }

    [Fact]
    public void Metrics_AllowOnlyBoundedPolicyLabelsAndRejectRawIdentifiers()
    {
        var metrics = new G05BoundedMetricRecorder();
        var metricNames = new[]
        {
            "ifx_context_validation_total",
            "ifx_envelope_validation_total",
            "ifx_tenant_rejection_total",
            "ifx_producer_rejection_total",
            "ifx_redaction_total",
            "ifx_compatibility_synthesis_total"
        };
        foreach (var metricName in metricNames)
        {
            metrics.Record(metricName, new Dictionary<string, string>
            {
                ["boundary"] = "pre_inbox",
                ["failure_class"] = "security",
                ["reason_code"] = "event_tenant_invalid",
                ["result"] = "quarantined"
            });
        }

        metrics.Measurements.Select(measurement => measurement.Name).Should().Equal(metricNames);
        var rawTenant = () => metrics.Record("ifx_tenant_rejection_total", new Dictionary<string, string>
        {
            ["tenantId"] = TenantId.ToString("D")
        });
        rawTenant.Should().Throw<ArgumentException>();
    }

    public static TheoryData<RawInboundEvent, string, G05FailureClass, string> InvalidCoreEvents => new()
    {
        { ValidRawEvent() with { EventType = "TransactionProcessed" }, "event_type_invalid", G05FailureClass.Permanent, "eventType" },
        { ValidRawEvent() with { SchemaVersion = "2" }, "event_version_unsupported", G05FailureClass.Permanent, "eventVersion" },
        { ValidRawEvent() with { EventId = Guid.Empty.ToString() }, "event_id_invalid", G05FailureClass.Permanent, "eventId" },
        { ValidRawEvent() with { Producer = "ifx.untrusted" }, "event_producer_denied", G05FailureClass.Security, "producer" },
        { ValidRawEvent() with { TenantId = "damaged" }, "event_tenant_invalid", G05FailureClass.Security, "tenant" },
        { ValidRawEvent() with { CorrelationId = Guid.Empty.ToString() }, "event_correlation_invalid", G05FailureClass.Permanent, "correlation" },
        { ValidRawEvent() with { CausationId = "damaged" }, "event_causation_invalid", G05FailureClass.Permanent, "causation" }
    };

    private static RawInboundEvent ValidRawEvent() => new(
        "ifx.transaction.transaction-processed.v1",
        "1",
        "11111111-1111-4111-8111-111111111111",
        "ifx.transaction",
        EventEnvelope.TenantScope,
        TenantId.ToString("D"),
        "33333333-3333-4333-8333-333333333333",
        "44444444-4444-4444-8444-444444444444",
        "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01",
        "{}");

    private static EventEnvelope CreateEnvelope() => new(
        Guid.Parse("11111111-1111-4111-8111-111111111111"),
        "ifx.transaction.transaction-processed.v1",
        1,
        Now,
        "ifx.transaction",
        EventEnvelope.TenantScope,
        TenantId,
        Guid.Parse("33333333-3333-4333-8333-333333333333"),
        Guid.Parse("44444444-4444-4444-8444-444444444444"));

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

public enum G05FailureClass
{
    Diagnostic,
    Client,
    Business,
    Transient,
    Permanent,
    Security
}

public enum G05FailureAction
{
    Continue,
    Reject,
    Complete,
    Retry,
    Quarantine,
    QuarantineAuditAlert
}

internal sealed record G05FailureDisposition(bool Retry, G05FailureAction Action);

internal static class G05FailureMatrix
{
    public static G05FailureDisposition Resolve(G05FailureClass failureClass) => failureClass switch
    {
        G05FailureClass.Diagnostic => new(false, G05FailureAction.Continue),
        G05FailureClass.Client => new(false, G05FailureAction.Reject),
        G05FailureClass.Business => new(false, G05FailureAction.Complete),
        G05FailureClass.Transient => new(true, G05FailureAction.Retry),
        G05FailureClass.Permanent => new(false, G05FailureAction.Quarantine),
        G05FailureClass.Security => new(false, G05FailureAction.QuarantineAuditAlert),
        _ => throw new ArgumentOutOfRangeException(nameof(failureClass))
    };
}

public sealed record RawInboundEvent(
    string EventType,
    string SchemaVersion,
    string EventId,
    string Producer,
    string Scope,
    string? TenantId,
    string CorrelationId,
    string CausationId,
    string? TraceParent,
    string Payload);

internal sealed record G05ValidationResult(
    bool Accepted,
    string Code,
    G05FailureClass? FailureClass,
    bool TraceRestarted,
    IReadOnlyList<string> ValidationTrace);

internal sealed partial class G05PreInboxValidator(IReadOnlySet<string> allowedProducers)
{
    public G05ValidationResult ValidateThenAccept(string consumer, RawInboundEvent message, G05FakeInbox inbox)
    {
        var trace = new List<string>();
        trace.Add("eventType");
        if (!EventTypePattern().IsMatch(message.EventType)) return Fail("event_type_invalid", G05FailureClass.Permanent, trace);

        trace.Add("eventVersion");
        if (message.SchemaVersion != "1" || !message.EventType.EndsWith(".v1", StringComparison.Ordinal))
            return Fail("event_version_unsupported", G05FailureClass.Permanent, trace);

        trace.Add("eventId");
        if (!TryIdentifier(message.EventId, out var eventId)) return Fail("event_id_invalid", G05FailureClass.Permanent, trace);

        trace.Add("producer");
        if (!allowedProducers.Contains(message.Producer)) return Fail("event_producer_denied", G05FailureClass.Security, trace);

        trace.Add("tenant");
        if (message.Scope != EventEnvelope.TenantScope || !TryIdentifier(message.TenantId, out _))
            return Fail("event_tenant_invalid", G05FailureClass.Security, trace);

        trace.Add("correlation");
        if (!TryIdentifier(message.CorrelationId, out _)) return Fail("event_correlation_invalid", G05FailureClass.Permanent, trace);

        trace.Add("causation");
        if (!TryIdentifier(message.CausationId, out _)) return Fail("event_causation_invalid", G05FailureClass.Permanent, trace);

        inbox.TryComplete(consumer, eventId);
        if (!IsValidTraceParent(message.TraceParent))
            return new(true, "event_trace_restarted", G05FailureClass.Diagnostic, true, trace);

        return new(true, "accepted", null, false, trace);
    }

    private static G05ValidationResult Fail(string code, G05FailureClass failureClass, IReadOnlyList<string> trace) =>
        new(false, code, failureClass, false, trace);

    private static bool TryIdentifier(string? value, out Guid identifier) =>
        Guid.TryParseExact(value, "D", out identifier) && identifier != Guid.Empty;

    private static bool IsValidTraceParent(string? value) => value is null || TraceParentPattern().IsMatch(value);

    [GeneratedRegex("^ifx\\.[a-z0-9-]+(?:\\.[a-z0-9-]+)+\\.v[1-9][0-9]*$")]
    private static partial Regex EventTypePattern();

    [GeneratedRegex("^00-[0-9a-f]{32}-[0-9a-f]{16}-[0-9a-f]{2}$")]
    private static partial Regex TraceParentPattern();
}

internal sealed class G05FakeInbox
{
    private readonly HashSet<string> completed = new(StringComparer.Ordinal);
    public int WriteCount { get; private set; }

    public bool TryComplete(string consumer, Guid eventId)
    {
        var added = completed.Add($"{consumer}:{eventId:D}");
        if (added) WriteCount++;
        return added;
    }
}

internal sealed record G05QuarantineRecord(
    ReadOnlyMemory<byte> EnvelopeBytes,
    ReadOnlyMemory<byte> PayloadBytes,
    IReadOnlyDictionary<string, string> SafeMetadata);

internal sealed record G05SecurityAudit(string ReasonCode, string SourceIdentity, string AlertKey);
internal sealed record G05BoundedAlert(string ReasonCode, string FailureClass, string AlertKey);

internal sealed class G05FakeQuarantineStore
{
    public List<G05SecurityAudit> SecurityAudits { get; } = [];
    public List<G05BoundedAlert> Alerts { get; } = [];

    public G05QuarantineRecord Capture(
        byte[] envelopeBytes,
        byte[] payloadBytes,
        G05FailureClass failureClass,
        string reasonCode,
        string sourceIdentity,
        string rawException,
        DateTimeOffset detectedAt)
    {
        _ = rawException; // Deliberately excluded from quarantine diagnostics.
        if (failureClass is not (G05FailureClass.Permanent or G05FailureClass.Security))
            throw new ArgumentException("Only permanent and security failures can be quarantined.", nameof(failureClass));

        var alertKey = $"{sourceIdentity}:{reasonCode}";
        var metadata = new Dictionary<string, string>(StringComparer.Ordinal)
        {
            ["reasonCode"] = reasonCode,
            ["failureClass"] = failureClass.ToString(),
            ["sourceIdentity"] = sourceIdentity,
            ["firstDetectedAt"] = detectedAt.ToString("O", CultureInfo.InvariantCulture),
            ["lastDetectedAt"] = detectedAt.ToString("O", CultureInfo.InvariantCulture),
            ["detectionCount"] = "1",
            ["alertKey"] = alertKey
        };

        Alerts.Add(new(reasonCode, failureClass.ToString(), alertKey));
        if (failureClass == G05FailureClass.Security)
            SecurityAudits.Add(new(reasonCode, sourceIdentity, alertKey));

        return new(envelopeBytes.ToArray(), payloadBytes.ToArray(), metadata);
    }
}

internal sealed record G05FrozenLogicalMessage(ReadOnlyMemory<byte> EnvelopeBytes, ReadOnlyMemory<byte> PayloadBytes);

internal sealed class G05DeliveryMetadata
{
    public int AttemptCount { get; set; }
    public string? Lease { get; set; }
    public DateTimeOffset? NextAttemptAt { get; set; }
    public string? LastErrorCode { get; set; }
}

internal sealed class G05DeliveryWork(G05FrozenLogicalMessage logical)
{
    public G05FrozenLogicalMessage Logical { get; } = logical;
    public G05DeliveryMetadata Delivery { get; } = new();

    public void RecordTransientFailure(string errorCode, string lease, DateTimeOffset nextAttemptAt)
    {
        Delivery.AttemptCount++;
        Delivery.Lease = lease;
        Delivery.NextAttemptAt = nextAttemptAt;
        Delivery.LastErrorCode = errorCode;
    }
}

internal sealed record G05ReplayResult(Guid EventId, string Status);

internal sealed class G05DeadLetterReplayer
{
    public G05ReplayResult Replay(string consumer, EventEnvelope original, G05FakeInbox inbox) =>
        new(original.EventId, inbox.TryComplete(consumer, original.EventId) ? "applied" : "duplicate");
}

internal sealed record G05ReprocessingRequest(
    Guid RequestId,
    Guid OriginalEventId,
    string ReasonCode,
    string RequestedByReference,
    string ApprovalReference,
    DateTimeOffset RequestedAt)
{
    public static G05ReprocessingRequest Create(
        Guid originalEventId,
        string reasonCode,
        string requestedByReference,
        string approvalReference,
        DateTimeOffset requestedAt)
    {
        if (string.IsNullOrWhiteSpace(approvalReference))
            throw new ArgumentException("Forced reprocessing requires a separate approval reference.", nameof(approvalReference));
        return new(Guid.NewGuid(), originalEventId, reasonCode, requestedByReference, approvalReference, requestedAt);
    }
}

internal sealed record G05CompatibilityRegistration(
    string AdapterId,
    string Owner,
    string SourceIdentity,
    IReadOnlySet<string> AllowedSynthesizedFields,
    DateTimeOffset ExpiresAt,
    string MetricReasonCode)
{
    private static readonly HashSet<string> AllowedFields = ["correlationId", "causationId"];

    public G05CompatibilityRegistration(
        string adapterId,
        string owner,
        string sourceIdentity,
        IEnumerable<string> allowedSynthesizedFields,
        DateTimeOffset expiresAt,
        string metricReasonCode)
        : this(adapterId, owner, sourceIdentity, allowedSynthesizedFields.ToHashSet(StringComparer.Ordinal), expiresAt, metricReasonCode)
    {
        if (AllowedSynthesizedFields.Count == 0 || !AllowedSynthesizedFields.IsSubsetOf(AllowedFields))
            throw new ArgumentException("Compatibility adapters may synthesize correlationId and causationId only.", nameof(allowedSynthesizedFields));
    }
}

internal sealed class G05CompatibilityException(string code) : Exception(code)
{
    public string Code { get; } = code;
}

internal sealed class G05CompatibilityRegistry
{
    private readonly IReadOnlyDictionary<string, G05CompatibilityRegistration> registrations;
    private readonly G05BoundedMetricRecorder metrics;

    private G05CompatibilityRegistry(IEnumerable<G05CompatibilityRegistration> registrations, G05BoundedMetricRecorder metrics)
    {
        this.registrations = registrations.ToDictionary(item => item.AdapterId, StringComparer.Ordinal);
        this.metrics = metrics;
    }

    public static G05CompatibilityRegistry CreateDefault(G05BoundedMetricRecorder metrics) => new(
        [new G05CompatibilityRegistration(
            "legacy-event-correlation-v1",
            "xiaolong-feng",
            "ifx.legacy-event-import",
            ["correlationId", "causationId"],
            DateTimeOffset.Parse("2026-12-01T00:00:00Z", CultureInfo.InvariantCulture),
            "legacy_context_synthesized")],
        metrics);

    public EventEnvelope Adapt(string adapterId, RawInboundEvent source, DateTimeOffset now)
    {
        if (!registrations.TryGetValue(adapterId, out var registration))
            throw new G05CompatibilityException("compatibility_adapter_unregistered");
        if (now >= registration.ExpiresAt)
            throw new G05CompatibilityException("compatibility_adapter_expired");
        if (!string.Equals(source.Producer, registration.SourceIdentity, StringComparison.Ordinal))
            throw new G05CompatibilityException("compatibility_source_denied");

        var correlation = ParseOrSynthesize(source.CorrelationId, "correlationId", registration);
        var causation = ParseOrSynthesize(source.CausationId, "causationId", registration);
        metrics.Record("ifx_compatibility_synthesis_total", new Dictionary<string, string>
        {
            ["adapter_id"] = registration.AdapterId,
            ["reason_code"] = registration.MetricReasonCode,
            ["provenance"] = EventEnvelope.SynthesizedProvenance,
            ["result"] = "adapted"
        });

        return new EventEnvelope(
            Guid.Parse(source.EventId), source.EventType, int.Parse(source.SchemaVersion, CultureInfo.InvariantCulture),
            now, source.Producer, source.Scope, Guid.Parse(source.TenantId!), correlation, causation,
            provenance: EventEnvelope.SynthesizedProvenance);
    }

    private static Guid ParseOrSynthesize(
        string value,
        string field,
        G05CompatibilityRegistration registration)
    {
        if (Guid.TryParseExact(value, "D", out var parsed) && parsed != Guid.Empty) return parsed;
        if (!registration.AllowedSynthesizedFields.Contains(field))
            throw new G05CompatibilityException("compatibility_field_not_allowed");
        return Guid.NewGuid();
    }
}

internal sealed record G05MetricMeasurement(string Name, IReadOnlyDictionary<string, string> Labels);

internal sealed partial class G05BoundedMetricRecorder
{
    private static readonly HashSet<string> AllowedNames =
    [
        "ifx_context_validation_total", "ifx_envelope_validation_total", "ifx_tenant_rejection_total",
        "ifx_producer_rejection_total", "ifx_redaction_total", "ifx_compatibility_synthesis_total"
    ];
    private static readonly HashSet<string> AllowedLabels =
    ["boundary", "failure_class", "reason_code", "result", "provenance", "adapter_id"];

    public List<G05MetricMeasurement> Measurements { get; } = [];

    public void Record(string name, IReadOnlyDictionary<string, string> labels)
    {
        if (!AllowedNames.Contains(name) || labels.Any(label =>
                !AllowedLabels.Contains(label.Key) || !BoundedValuePattern().IsMatch(label.Value)))
            throw new ArgumentException("Metric names and labels must use bounded policy identifiers only.");
        Measurements.Add(new(name, new Dictionary<string, string>(labels, StringComparer.Ordinal)));
    }

    [GeneratedRegex("^[a-z0-9][a-z0-9_.-]{0,63}$")]
    private static partial Regex BoundedValuePattern();
}
