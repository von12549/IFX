using IFX.Platform.Messaging.Contracts.Events;

namespace IFX.Modules.Registry.Contracts.V1.Events;

public sealed record ClassStatusChangedV1(
    Guid ClassId,
    Guid FundId,
    string OldStatus,
    string NewStatus) : IIntegrationEventV1
{
    public const string EventType = "ifx.registry.class-status-changed.v1";
    public const int SchemaVersion = 1;
}
