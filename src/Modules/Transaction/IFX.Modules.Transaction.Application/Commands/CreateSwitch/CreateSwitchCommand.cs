using IFX.Modules.Transaction.Application.Common;
using IFX.Modules.Transaction.Application.DTOs;
using MediatR;
namespace IFX.Modules.Transaction.Application.Commands.CreateSwitch;
public record CreateSwitchCommand(
    Guid PartyId, Guid InvestorId, Guid FundId,
    Guid ClassId, Guid TargetClassId,
    decimal Amount, DateOnly TradeDate
) : IRequest<Result<TransactionDto>>;
