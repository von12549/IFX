using IFX.Modules.Holdings.Application.Interfaces;
using IFX.Modules.Holdings.Domain.Entities;
using IFX.Modules.Transaction.Abstractions.Events;
using IFX.Platform.Messaging.Abstractions;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.Holdings.Application.EventHandlers;

public class TransactionProcessedEventHandler : IIntegrationEventHandler<TransactionProcessedEvent>
{
    private readonly IUnitOfWork _unitOfWork;
    private readonly ILogger<TransactionProcessedEventHandler> _logger;

    public TransactionProcessedEventHandler(IUnitOfWork unitOfWork, ILogger<TransactionProcessedEventHandler> logger)
    {
        _unitOfWork = unitOfWork;
        _logger = logger;
    }

    public async Task HandleAsync(TransactionProcessedEvent @event, CancellationToken ct = default)
    {
        _logger.LogInformation("Processing transaction {TransactionId} ({Type}) for account {InvestmentAccountId} class {ClassId}",
            @event.TransactionId, @event.TransactionType, @event.InvestmentAccountId, @event.ClassId);

        switch (@event.TransactionType)
        {
            case "Subscription":
                await ApplySubscriptionAsync(@event, ct);
                break;
            case "Redemption":
                await ApplyRedemptionAsync(@event, ct);
                break;
            case "Transfer":
            case "Switch":
                await ApplyTransferAsync(@event, ct);
                break;
            default:
                _logger.LogWarning("Unknown transaction type: {TransactionType}", @event.TransactionType);
                break;
        }
    }

    private async Task ApplySubscriptionAsync(TransactionProcessedEvent @event, CancellationToken ct)
    {
        var holding = await GetOrCreateHoldingAsync(@event.TenantId, @event.InvestmentAccountId, @event.ClassId, ct);
        holding.ApplySubscription(@event.Units);
        await _unitOfWork.SaveChangesAsync(ct);
    }

    private async Task ApplyRedemptionAsync(TransactionProcessedEvent @event, CancellationToken ct)
    {
        var holding = await _unitOfWork.Holdings.GetByAccountAndClassAsync(@event.TenantId, @event.InvestmentAccountId, @event.ClassId, ct);
        if (holding == null)
        {
            _logger.LogWarning("No holding found for account {InvestmentAccountId} class {ClassId}", @event.InvestmentAccountId, @event.ClassId);
            return;
        }
        holding.ApplyRedemption(@event.Units);
        _unitOfWork.Holdings.Update(holding);
        await _unitOfWork.SaveChangesAsync(ct);
    }

    private async Task ApplyTransferAsync(TransactionProcessedEvent @event, CancellationToken ct)
    {
        // Decrement source class holding
        var sourceHolding = await _unitOfWork.Holdings.GetByAccountAndClassAsync(@event.TenantId, @event.InvestmentAccountId, @event.ClassId, ct);
        if (sourceHolding != null)
        {
            sourceHolding.ApplyTransfer(@event.Units);
            _unitOfWork.Holdings.Update(sourceHolding);
        }

        // Increment target class holding (upsert)
        if (@event.TargetClassId.HasValue)
        {
            var targetHolding = await GetOrCreateHoldingAsync(@event.TenantId, @event.InvestmentAccountId, @event.TargetClassId.Value, ct);
            targetHolding.ApplySubscription(@event.Units);
        }

        await _unitOfWork.SaveChangesAsync(ct);
    }

    private async Task<Holding> GetOrCreateHoldingAsync(Guid tenantId, Guid investmentAccountId, Guid classId, CancellationToken ct)
    {
        var holding = await _unitOfWork.Holdings.GetByAccountAndClassAsync(tenantId, investmentAccountId, classId, ct);
        if (holding != null) return holding;

        holding = Holding.Create(tenantId, investmentAccountId, classId);
        await _unitOfWork.Holdings.AddAsync(holding, ct);
        return holding;
    }
}
