using IFX.BuildingBlocks.Application.Commands;
using IFX.BuildingBlocks.Application.Events;
using IFX.BuildingBlocks.Application.Transactions;
using IFX.Modules.Holdings.Application.Interfaces;
using IFX.Modules.Holdings.Application.Ports;
using IFX.Modules.Holdings.Application.Transactions;
using MediatR;

namespace IFX.Modules.Holdings.Application.Integrations;

public sealed record ApplyClassStatusChangedCommand(
    IntegrationEventMetadata Metadata,
    Guid ClassId,
    Guid FundId,
    string OldStatus,
    string NewStatus) : ICommand<InboxCommandResult, HoldingsTransactionOwner>, IInboxCommand
{
    public string ConsumerId => "holdings.class-status-changed.v1";
    public TransactionProfile TransactionProfile => TransactionProfile.Inbox;
}

public sealed class ApplyClassStatusChangedCommandHandler(
    IUnitOfWork unitOfWork,
    IHoldingsInboxPort inbox) : IRequestHandler<ApplyClassStatusChangedCommand, InboxCommandResult>
{
    public async Task<InboxCommandResult> Handle(ApplyClassStatusChangedCommand request, CancellationToken cancellationToken)
    {
        if (await inbox.HasCompletedAsync(request.ConsumerId, request.Metadata.EventId, cancellationToken))
        {
            return InboxCommandResult.Duplicate();
        }

        if (request.NewStatus is "Closed" or "Liquidating")
        {
            var holdings = await unitOfWork.Holdings.GetByClassAsync(request.Metadata.TenantId, request.ClassId, cancellationToken);
            foreach (var holding in holdings)
            {
                holding.Freeze();
                unitOfWork.Holdings.Update(holding);
            }
        }

        return InboxCommandResult.Applied();
    }
}
