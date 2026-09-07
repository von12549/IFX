using IFX.BuildingBlocks.Application.Commands;
using IFX.Modules.Transaction.Application.Transactions;
using IFX.Modules.Transaction.Application.Common;
using IFX.Modules.Transaction.Application.DTOs;
using MediatR;
namespace IFX.Modules.Transaction.Application.Commands.CreateSubscription;
public record CreateSubscriptionCommand(
    Guid InvestmentAccountId, Guid FundId, Guid ClassId,
    decimal Amount, DateOnly TradeDate
) : ICommand<Result<TransactionDto>, TransactionModuleOwner>;
