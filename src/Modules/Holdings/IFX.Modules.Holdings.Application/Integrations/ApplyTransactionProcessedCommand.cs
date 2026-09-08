using IFX.BuildingBlocks.Application.Commands;
using IFX.BuildingBlocks.Application.Events;
using IFX.BuildingBlocks.Application.Transactions;
using IFX.Modules.Holdings.Application.Interfaces;
using IFX.Modules.Holdings.Application.Ports;
using IFX.Modules.Holdings.Application.Transactions;
using IFX.Modules.Holdings.Domain.Entities;
using MediatR;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.Holdings.Application.Integrations;

public sealed record ApplyTransactionProcessedCommand(
    IntegrationEventMetadata Metadata,
    Guid TransactionId,
    string TransactionType,
    Guid InvestmentAccountId,
    Guid ClassId,
    Guid? TargetClassId,
    decimal Units,
    decimal NavPrice) : ICommand<InboxCommandResult, HoldingsTransactionOwner>, IInboxCommand
{
    public string ConsumerId => "holdings.transaction-processed.v1";
    public TransactionProfile TransactionProfile => TransactionProfile.Inbox;
}

public sealed class ApplyTransactionProcessedCommandHandler(
    IUnitOfWork unitOfWork,
    IHoldingsInboxPort inbox,
    ILogger<ApplyTransactionProcessedCommandHandler> logger) : IRequestHandler<ApplyTransactionProcessedCommand, InboxCommandResult>
{
    public async Task<InboxCommandResult> Handle(ApplyTransactionProcessedCommand request, CancellationToken cancellationToken)
    {
        if (await inbox.HasCompletedAsync(request.ConsumerId, request.Metadata.EventId, cancellationToken))
        {
            return InboxCommandResult.Duplicate();
        }

        switch (request.TransactionType)
        {
            case "Subscription":
                (await GetOrCreateAsync(request.Metadata.TenantId, request.InvestmentAccountId, request.ClassId, cancellationToken)).ApplySubscription(request.Units);
                break;
            case "Redemption":
                var redemption = await unitOfWork.Holdings.GetByAccountAndClassAsync(request.Metadata.TenantId, request.InvestmentAccountId, request.ClassId, cancellationToken);
                if (redemption is null) return InboxCommandResult.Rejected();
                redemption.ApplyRedemption(request.Units);
                unitOfWork.Holdings.Update(redemption);
                break;
            case "Transfer":
            case "Switch":
                var source = await unitOfWork.Holdings.GetByAccountAndClassAsync(request.Metadata.TenantId, request.InvestmentAccountId, request.ClassId, cancellationToken);
                if (source is null || request.TargetClassId is null) return InboxCommandResult.Rejected();
                source.ApplyTransfer(request.Units);
                unitOfWork.Holdings.Update(source);
                (await GetOrCreateAsync(request.Metadata.TenantId, request.InvestmentAccountId, request.TargetClassId.Value, cancellationToken)).ApplySubscription(request.Units);
                break;
            default:
                logger.LogWarning("Rejected transaction event {EventId}: unsupported transaction type", request.Metadata.EventId);
                return InboxCommandResult.Rejected();
        }

        return InboxCommandResult.Applied();
    }

    private async Task<Holding> GetOrCreateAsync(Guid tenantId, Guid accountId, Guid classId, CancellationToken cancellationToken)
    {
        var holding = await unitOfWork.Holdings.GetByAccountAndClassAsync(tenantId, accountId, classId, cancellationToken);
        if (holding is not null) return holding;
        holding = Holding.Create(tenantId, accountId, classId);
        await unitOfWork.Holdings.AddAsync(holding, cancellationToken);
        return holding;
    }
}
