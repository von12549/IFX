using IFX.Modules.Transaction.Application.Common;
using IFX.Modules.Transaction.Application.DTOs;
using MediatR;
namespace IFX.Modules.Transaction.Application.Commands.CreateRedemption;
public record CreateRedemptionCommand(
    Guid InvestmentAccountId, Guid FundId, Guid ClassId,
    decimal Amount, DateOnly TradeDate
) : IRequest<Result<TransactionDto>>;
