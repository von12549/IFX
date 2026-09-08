using IFX.Modules.Holdings.Infrastructure.Persistence;
using IFX.Platform.Messaging.Runtime;
using Microsoft.EntityFrameworkCore;

namespace IFX.Modules.Holdings.Infrastructure.Messaging;

public sealed class HoldingsInboxDiagnosticStore(HoldingsDbContext dbContext) : IModuleInboxDiagnosticStore
{
    public string ModuleId => "holdings";

    public async Task<IReadOnlyList<InboxDiagnosticRecord>> QueryAsync(
        InboxDiagnosticQuery query,
        CancellationToken cancellationToken)
    {
        var messages = dbContext.InboxMessages.AsNoTracking();
        if (query.EventId is { } eventId) messages = messages.Where(message => message.EventId == eventId);
        if (query.From is { } from) messages = messages.Where(message => message.CompletedAt >= from);
        if (query.To is { } to) messages = messages.Where(message => message.CompletedAt <= to);
        if (!string.IsNullOrWhiteSpace(query.EventType)) messages = messages.Where(message => message.EventType == query.EventType);
        if (query.TenantId is { } tenantId) messages = messages.Where(message => message.TenantId == tenantId);
        var limit = Math.Clamp(query.Limit, 1, 500);
        return await messages.OrderByDescending(message => message.CompletedAt).Take(limit)
            .Select(message => new InboxDiagnosticRecord(
                message.EventId, ModuleId, message.ConsumerId, message.EventType, message.TenantId, message.CompletedAt))
            .ToListAsync(cancellationToken);
    }
}
