using IFX.Modules.Transaction.Application.Commands.CancelTransaction;
using IFX.Modules.Transaction.Application.Commands.CreateRedemption;
using IFX.Modules.Transaction.Application.Commands.CreateSubscription;
using IFX.Modules.Transaction.Application.Commands.CreateSwitch;
using IFX.Modules.Transaction.Application.Commands.CreateTransfer;
using IFX.Modules.Transaction.Application.Commands.ProcessTransaction;
using IFX.Modules.Transaction.Application.Queries.GetTransactionById;
using IFX.Modules.Transaction.Application.Queries.GetTransactions;
using IFX.Modules.Transaction.Presentation.Models.Responses;
using IFX.Modules.Transaction.Presentation.Requests;
using MediatR;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.Transaction.Presentation.Transactions.Endpoints;

public sealed class TransactionEndpointsLogCategory { }

public static class TransactionEndpoints
{
    public static async Task<IResult> GetTransactions(
        [FromServices] IMediator mediator,
        [FromServices] ILogger<TransactionEndpointsLogCategory> logger)
    {
        logger.LogInformation("Listing transactions");
        var result = await mediator.Send(new GetTransactionsQuery());
        if (!result.IsSuccess) return Results.BadRequest(ApiResponse<object>.FailureResponse(result.Error!));
        return Results.Ok(ApiResponse<object>.SuccessResponse(result.Value!));
    }

    public static async Task<IResult> GetTransactionById(
        Guid transactionId,
        [FromServices] IMediator mediator,
        [FromServices] ILogger<TransactionEndpointsLogCategory> logger)
    {
        logger.LogInformation("Getting transaction {TransactionId}", transactionId);
        var result = await mediator.Send(new GetTransactionByIdQuery(transactionId));
        if (!result.IsSuccess) return Results.NotFound(ApiResponse<object>.FailureResponse(result.Error!));
        return Results.Ok(ApiResponse<object>.SuccessResponse(result.Value!));
    }

    public static async Task<IResult> CreateSubscription(
        [FromBody] CreateSubscriptionRequest request,
        [FromServices] IMediator mediator,
        [FromServices] ILogger<TransactionEndpointsLogCategory> logger)
    {
        logger.LogInformation("Creating subscription for investor {InvestorId}", request.InvestorId);

        if (!DateOnly.TryParse(request.TradeDate, out var tradeDate))
            return Results.BadRequest(ApiResponse<object>.FailureResponse("Invalid TradeDate format. Use yyyy-MM-dd."));

        var command = new CreateSubscriptionCommand(request.PartyId, request.InvestorId, request.FundId, request.ClassId, request.Amount, tradeDate);
        var result = await mediator.Send(command);
        if (!result.IsSuccess) return Results.BadRequest(ApiResponse<object>.FailureResponse(result.Error!));
        return Results.Created($"/api/v1/transaction/{result.Value!.TransactionId}", ApiResponse<object>.SuccessResponse(result.Value!));
    }

    public static async Task<IResult> CreateRedemption(
        [FromBody] CreateRedemptionRequest request,
        [FromServices] IMediator mediator,
        [FromServices] ILogger<TransactionEndpointsLogCategory> logger)
    {
        logger.LogInformation("Creating redemption for investor {InvestorId}", request.InvestorId);

        if (!DateOnly.TryParse(request.TradeDate, out var tradeDate))
            return Results.BadRequest(ApiResponse<object>.FailureResponse("Invalid TradeDate format. Use yyyy-MM-dd."));

        var command = new CreateRedemptionCommand(request.PartyId, request.InvestorId, request.FundId, request.ClassId, request.Amount, tradeDate);
        var result = await mediator.Send(command);
        if (!result.IsSuccess) return Results.BadRequest(ApiResponse<object>.FailureResponse(result.Error!));
        return Results.Created($"/api/v1/transaction/{result.Value!.TransactionId}", ApiResponse<object>.SuccessResponse(result.Value!));
    }

    public static async Task<IResult> CreateTransfer(
        [FromBody] CreateTransferRequest request,
        [FromServices] IMediator mediator,
        [FromServices] ILogger<TransactionEndpointsLogCategory> logger)
    {
        logger.LogInformation("Creating transfer for investor {InvestorId}", request.InvestorId);

        if (!DateOnly.TryParse(request.TradeDate, out var tradeDate))
            return Results.BadRequest(ApiResponse<object>.FailureResponse("Invalid TradeDate format. Use yyyy-MM-dd."));

        var command = new CreateTransferCommand(request.PartyId, request.InvestorId, request.FundId, request.ClassId, request.TargetClassId, request.Amount, tradeDate);
        var result = await mediator.Send(command);
        if (!result.IsSuccess) return Results.BadRequest(ApiResponse<object>.FailureResponse(result.Error!));
        return Results.Created($"/api/v1/transaction/{result.Value!.TransactionId}", ApiResponse<object>.SuccessResponse(result.Value!));
    }

    public static async Task<IResult> CreateSwitch(
        [FromBody] CreateSwitchRequest request,
        [FromServices] IMediator mediator,
        [FromServices] ILogger<TransactionEndpointsLogCategory> logger)
    {
        logger.LogInformation("Creating switch for investor {InvestorId}", request.InvestorId);

        if (!DateOnly.TryParse(request.TradeDate, out var tradeDate))
            return Results.BadRequest(ApiResponse<object>.FailureResponse("Invalid TradeDate format. Use yyyy-MM-dd."));

        var command = new CreateSwitchCommand(request.PartyId, request.InvestorId, request.FundId, request.ClassId, request.TargetClassId, request.Amount, tradeDate);
        var result = await mediator.Send(command);
        if (!result.IsSuccess) return Results.BadRequest(ApiResponse<object>.FailureResponse(result.Error!));
        return Results.Created($"/api/v1/transaction/{result.Value!.TransactionId}", ApiResponse<object>.SuccessResponse(result.Value!));
    }

    public static async Task<IResult> ProcessTransaction(
        Guid transactionId,
        [FromBody] ProcessTransactionRequest request,
        [FromServices] IMediator mediator,
        [FromServices] ILogger<TransactionEndpointsLogCategory> logger)
    {
        logger.LogInformation("Processing transaction {TransactionId}", transactionId);
        var command = new ProcessTransactionCommand(transactionId, request.NAVPrice);
        var result = await mediator.Send(command);
        if (!result.IsSuccess) return Results.BadRequest(ApiResponse<object>.FailureResponse(result.Error!));
        return Results.Ok(ApiResponse<object>.SuccessResponse(result.Value!));
    }

    public static async Task<IResult> CancelTransaction(
        Guid transactionId,
        [FromBody] CancelTransactionRequest request,
        [FromServices] IMediator mediator,
        [FromServices] ILogger<TransactionEndpointsLogCategory> logger)
    {
        logger.LogInformation("Cancelling transaction {TransactionId}", transactionId);
        var command = new CancelTransactionCommand(transactionId, request.Reason);
        var result = await mediator.Send(command);
        if (!result.IsSuccess) return Results.BadRequest(ApiResponse<object>.FailureResponse(result.Error!));
        return Results.Ok(ApiResponse<object>.SuccessResponse(result.Value!));
    }
}
