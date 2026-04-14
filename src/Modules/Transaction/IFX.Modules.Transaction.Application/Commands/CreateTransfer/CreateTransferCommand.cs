using IFX.Modules.Transaction.Application.Common;
using IFX.Modules.Transaction.Application.DTOs;
using MediatR;
namespace IFX.Modules.Transaction.Application.Commands.CreateTransfer;
public record CreateTransferCommand(
    Guid InvestmentAccountId, Guid FundId,
    Guid ClassId, Guid TargetClassId,
    decimal Amount, DateOnly TradeDate
) : IRequest<Result<TransactionDto>>;
