using IFX.Modules.Transaction.Application.Common;
using IFX.Modules.Transaction.Application.DTOs;
using MediatR;
namespace IFX.Modules.Transaction.Application.Commands.CreateSubscription;
public record CreateSubscriptionCommand(
    Guid PartyId, Guid InvestorId, Guid FundId, Guid ClassId,
    decimal Amount, DateOnly TradeDate
) : IRequest<Result<TransactionDto>>;
