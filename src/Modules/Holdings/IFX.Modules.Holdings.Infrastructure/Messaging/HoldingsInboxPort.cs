using IFX.Modules.Holdings.Application.Integrations;
using IFX.Modules.Holdings.Application.Ports;
using IFX.Modules.Holdings.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;

namespace IFX.Modules.Holdings.Infrastructure.Messaging;

public sealed class HoldingsInboxPort(HoldingsDbContext dbContext) : IHoldingsInboxPort
{
    public Task<bool> HasCompletedAsync(string consumerId, Guid eventId, CancellationToken cancellationToken) =>
        dbContext.InboxMessages.AnyAsync(message => message.ConsumerId == consumerId && message.EventId == eventId, cancellationToken);
}
