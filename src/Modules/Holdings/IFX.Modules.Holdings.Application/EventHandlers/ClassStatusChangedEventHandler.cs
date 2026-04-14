using IFX.Modules.Holdings.Application.Interfaces;
using IFX.Modules.Registry.Abstractions.Events;
using IFX.Platform.Messaging.Abstractions;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.Holdings.Application.EventHandlers;

public class ClassStatusChangedEventHandler : IIntegrationEventHandler<ClassStatusChangedEvent>
{
    private readonly IUnitOfWork _unitOfWork;
    private readonly ILogger<ClassStatusChangedEventHandler> _logger;

    public ClassStatusChangedEventHandler(IUnitOfWork unitOfWork, ILogger<ClassStatusChangedEventHandler> logger)
    {
        _unitOfWork = unitOfWork;
        _logger = logger;
    }

    public async Task HandleAsync(ClassStatusChangedEvent @event, CancellationToken ct = default)
    {
        if (@event.NewStatus is not ("Closed" or "Liquidating"))
            return;

        _logger.LogInformation("Class {ClassId} status changed to {Status}. Freezing holdings.", @event.ClassId, @event.NewStatus);

        var holdings = await _unitOfWork.Holdings.GetByClassAsync(@event.TenantId, @event.ClassId, ct);

        foreach (var holding in holdings)
        {
            holding.Freeze();
            _unitOfWork.Holdings.Update(holding);
        }

        await _unitOfWork.SaveChangesAsync(ct);
    }
}
