using IFX.Platform.Messaging.Contracts;
using IFX.Platform.Messaging.Contracts.Messaging;

namespace IFX.Platform.ProtocolContracts.Tests;

public sealed class EventEnvelopeV1Tests
{
    [Fact]
    public void Constructor_WithTenantEnvelope_PreservesLogicalMetadata()
    {
        var eventId = Guid.NewGuid();
        var correlationId = Guid.NewGuid();
        var causationId = Guid.NewGuid();
        var tenantId = Guid.NewGuid();
        var occurredAt = DateTimeOffset.UtcNow;
        const string traceParent = "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01";

        var envelope = new EventEnvelope(
            eventId, "ifx.transaction.transaction-processed.v1", 1, occurredAt,
            "ifx.transaction", EventEnvelope.TenantScope, tenantId,
            correlationId, causationId, traceParent: traceParent, traceState: "vendor=value");

        envelope.EventId.Should().Be(eventId);
        envelope.OccurredAt.Should().Be(occurredAt);
        envelope.TenantId.Should().Be(tenantId);
        envelope.CorrelationId.Should().Be(correlationId);
        envelope.CausationId.Should().Be(causationId);
        envelope.TraceParent.Should().Be(traceParent);
    }

    [Fact]
    public void Constructor_WithNonUtcOccurrence_Throws()
    {
        var nonUtcOccurrence = new DateTimeOffset(2026, 9, 12, 12, 0, 0, TimeSpan.FromHours(10));
        var act = () => CreateEnvelope(nonUtcOccurrence);

        act.Should().Throw<ArgumentException>();
    }

    [Fact]
    public void Constructor_WithEmptyBusinessIdentity_Throws()
    {
        var act = () => new EventEnvelope(
            Guid.NewGuid(), "ifx.transaction.transaction-processed.v1", 1, DateTimeOffset.UtcNow,
            "ifx.transaction", EventEnvelope.PlatformScope, null, Guid.Empty, Guid.NewGuid());

        act.Should().Throw<ArgumentException>();
    }

    [Fact]
    public void Constructor_WithPlatformTenant_Throws()
    {
        var act = () => new EventEnvelope(
            Guid.NewGuid(), "ifx.transaction.transaction-processed.v1", 1, DateTimeOffset.UtcNow,
            "ifx.transaction", EventEnvelope.PlatformScope, Guid.NewGuid(), Guid.NewGuid(), Guid.NewGuid());

        act.Should().Throw<ArgumentException>();
    }

    [Theory]
    [InlineData("IFX.Transaction.Event.v1", 1)]
    [InlineData("ifx.transaction.event.v2", 1)]
    [InlineData("transaction.event.v1", 1)]
    public void Constructor_WithInvalidEventTypeOrVersion_Throws(string name, int version)
    {
        var act = () => new EventEnvelope(
            Guid.NewGuid(), name, version, DateTimeOffset.UtcNow,
            "ifx.transaction", EventEnvelope.PlatformScope, null, Guid.NewGuid(), Guid.NewGuid());

        act.Should().Throw<ArgumentException>();
    }

    [Theory]
    [InlineData("00-00000000000000000000000000000000-00f067aa0ba902b7-01")]
    [InlineData("00-4BF92F3577B34DA6A3CE929D0E0E4736-00f067aa0ba902b7-01")]
    [InlineData("invalid")]
    public void Constructor_WithInvalidTraceParent_Throws(string traceParent)
    {
        var act = () => new EventEnvelope(
            Guid.NewGuid(), "ifx.transaction.transaction-processed.v1", 1, DateTimeOffset.UtcNow,
            "ifx.transaction", EventEnvelope.PlatformScope, null, Guid.NewGuid(), Guid.NewGuid(),
            traceParent: traceParent);

        act.Should().Throw<ArgumentException>();
    }

    [Fact]
    public void EventIdentifier_CanonicalText_RoundTrips()
    {
        var identifier = EventIdentifier.New();

        EventIdentifier.Parse(identifier.ToString()).Should().Be(identifier);
    }

    [Fact]
    public void PublicShape_ContainsOnlyApprovedBclTypes()
    {
        var approved = new[] { typeof(int), typeof(Guid), typeof(Guid?), typeof(string), typeof(DateTimeOffset) };

        typeof(EventEnvelope).GetProperties()
            .Should().OnlyContain(property => approved.Contains(property.PropertyType));
    }

    private static EventEnvelope CreateEnvelope(DateTimeOffset occurredAt) => new(
        Guid.NewGuid(), "ifx.transaction.transaction-processed.v1", 1, occurredAt,
        "ifx.transaction", EventEnvelope.PlatformScope, null, Guid.NewGuid(), Guid.NewGuid());
}
