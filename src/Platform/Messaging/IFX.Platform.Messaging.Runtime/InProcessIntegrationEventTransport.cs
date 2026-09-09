namespace IFX.Platform.Messaging.Runtime;

public sealed class InProcessIntegrationEventTransport(IInboundIntegrationEventReceiver receiver) : IIntegrationEventSender
{
    public async Task SendAsync(OutboxLogicalMessage message, CancellationToken cancellationToken)
    {
        var result = await receiver.ReceiveAsync(
            IntegrationEventTransportCodec.Encode(message),
            cancellationToken);
        if (result.Disposition != InboundIntegrationEventDisposition.Accepted)
        {
            throw new InvalidOperationException(
                $"Inbound integration event was not accepted. ReasonCode={result.ReasonCode}.");
        }
    }
}
