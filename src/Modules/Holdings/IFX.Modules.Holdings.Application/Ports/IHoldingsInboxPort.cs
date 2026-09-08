namespace IFX.Modules.Holdings.Application.Ports;

public interface IHoldingsInboxPort
{
    Task<bool> HasCompletedAsync(string consumerId, Guid eventId, CancellationToken cancellationToken);
}
