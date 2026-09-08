using System.Text.Json;
using IFX.Modules.Registry.Contracts.V1.Events;
using IFX.Modules.Transaction.Contracts.V1.Events;
using IFX.Platform.Messaging.Contracts;

namespace IFX.Platform.ProtocolContracts.Tests;

public sealed class Plan02EventSchemaTests
{
    private static readonly JsonSerializerOptions Web = new(JsonSerializerDefaults.Web);

    [Fact]
    public void Provider_owned_v1_events_have_stable_schema_identities()
    {
        new EventSchemaIdentity(TransactionProcessedV1.EventType, TransactionProcessedV1.SchemaVersion).MajorVersion.Should().Be(1);
        new EventSchemaIdentity(ClassStatusChangedV1.EventType, ClassStatusChangedV1.SchemaVersion).MajorVersion.Should().Be(1);
    }

    [Fact]
    public void Transaction_payload_is_minimal_and_ignores_unknown_fields()
    {
        var payload = new TransactionProcessedV1(Guid.NewGuid(), "Subscription", Guid.NewGuid(), Guid.NewGuid(), null, 12.5m, 3.25m);
        var json = JsonSerializer.Serialize(payload, Web);

        json.Should().Contain("\"transactionId\"").And.Contain("\"navPrice\"");
        json.Contains("tenantId", StringComparison.OrdinalIgnoreCase).Should().BeFalse();
        var withUnknown = json[..^1] + ",\"futureField\":true}";
        JsonSerializer.Deserialize<TransactionProcessedV1>(withUnknown, Web).Should().Be(payload);
    }

    [Fact]
    public void Registry_payload_is_minimal_and_ignores_unknown_fields()
    {
        var payload = new ClassStatusChangedV1(Guid.NewGuid(), Guid.NewGuid(), "Open", "Closed");
        var json = JsonSerializer.Serialize(payload, Web);

        json.Should().Contain("\"classId\"").And.Contain("\"newStatus\"");
        json.Contains("tenantId", StringComparison.OrdinalIgnoreCase).Should().BeFalse();
        var withUnknown = json[..^1] + ",\"futureField\":true}";
        JsonSerializer.Deserialize<ClassStatusChangedV1>(withUnknown, Web).Should().Be(payload);
    }

}
