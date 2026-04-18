using IFX.Modules.Transaction.Application.Commands.AcceptOrder;
using IFX.Modules.Transaction.Application.Commands.CancelOrder;
using IFX.Modules.Transaction.Application.Commands.ConfirmOrder;
using IFX.Modules.Transaction.Application.Commands.CreateOrder;
using IFX.Modules.Transaction.Application.Commands.RejectOrder;
using IFX.Modules.Transaction.Application.Queries.GetOrderById;
using IFX.Modules.Transaction.Application.Queries.GetOrders;
using IFX.Modules.Transaction.Presentation.Models.Responses;
using IFX.Modules.Transaction.Presentation.Requests;
using MediatR;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.Transaction.Presentation.Orders.Endpoints;

public sealed class OrderEndpointsLogCategory { }

public static class OrderEndpoints
{
    public static async Task<IResult> GetOrders(
        [FromServices] IMediator mediator,
        [FromServices] ILogger<OrderEndpointsLogCategory> logger)
    {
        logger.LogInformation("Listing orders");
        var result = await mediator.Send(new GetOrdersQuery());
        if (!result.IsSuccess) return Results.BadRequest(ApiResponse<object>.FailureResponse(result.Error!));
        return Results.Ok(ApiResponse<object>.SuccessResponse(result.Value!));
    }

    public static async Task<IResult> GetOrderById(
        Guid orderId,
        [FromServices] IMediator mediator,
        [FromServices] ILogger<OrderEndpointsLogCategory> logger)
    {
        logger.LogInformation("Getting order {OrderId}", orderId);
        var result = await mediator.Send(new GetOrderByIdQuery(orderId));
        if (!result.IsSuccess) return Results.NotFound(ApiResponse<object>.FailureResponse(result.Error!));
        return Results.Ok(ApiResponse<object>.SuccessResponse(result.Value!));
    }

    public static async Task<IResult> CreateOrder(
        [FromBody] CreateOrderRequest request,
        [FromServices] IMediator mediator,
        [FromServices] ILogger<OrderEndpointsLogCategory> logger)
    {
        logger.LogInformation("Creating {OrderType} order", request.OrderType);

        if (!DateOnly.TryParse(request.TradeDate, out var tradeDate))
            return Results.BadRequest(ApiResponse<object>.FailureResponse("Invalid TradeDate format. Use yyyy-MM-dd."));

        var command = new CreateOrderCommand(
            request.OrderType, request.OrderReference, request.InvestmentAccountId,
            request.FromFundId, request.FromClassId, request.ToFundId, request.ToClassId,
            request.Amount, request.Currency, tradeDate);

        var result = await mediator.Send(command);
        if (!result.IsSuccess) return Results.BadRequest(ApiResponse<object>.FailureResponse(result.Error!));
        return Results.Created($"/api/v1/order/{result.Value!.OrderId}", ApiResponse<object>.SuccessResponse(result.Value!));
    }

    public static async Task<IResult> AcceptOrder(
        Guid orderId,
        [FromBody] AcceptOrderRequest request,
        [FromServices] IMediator mediator,
        [FromServices] ILogger<OrderEndpointsLogCategory> logger)
    {
        logger.LogInformation("Accepting order {OrderId}", orderId);

        DateOnly? expectedTradeDate = null;
        DateOnly? expectedSettlementDate = null;
        if (!string.IsNullOrWhiteSpace(request.ExpectedTradeDate) && !DateOnly.TryParse(request.ExpectedTradeDate, out var etd))
            return Results.BadRequest(ApiResponse<object>.FailureResponse("Invalid ExpectedTradeDate format. Use yyyy-MM-dd."));
        else if (!string.IsNullOrWhiteSpace(request.ExpectedTradeDate))
            expectedTradeDate = DateOnly.Parse(request.ExpectedTradeDate);

        if (!string.IsNullOrWhiteSpace(request.ExpectedSettlementDate) && !DateOnly.TryParse(request.ExpectedSettlementDate, out var esd))
            return Results.BadRequest(ApiResponse<object>.FailureResponse("Invalid ExpectedSettlementDate format. Use yyyy-MM-dd."));
        else if (!string.IsNullOrWhiteSpace(request.ExpectedSettlementDate))
            expectedSettlementDate = DateOnly.Parse(request.ExpectedSettlementDate);

        var command = new AcceptOrderCommand(orderId, request.DealReference, expectedTradeDate, expectedSettlementDate);
        var result = await mediator.Send(command);
        if (!result.IsSuccess) return Results.BadRequest(ApiResponse<object>.FailureResponse(result.Error!));
        return Results.Ok(ApiResponse<object>.SuccessResponse(result.Value!));
    }

    public static async Task<IResult> RejectOrder(
        Guid orderId,
        [FromBody] RejectOrderRequest request,
        [FromServices] IMediator mediator,
        [FromServices] ILogger<OrderEndpointsLogCategory> logger)
    {
        logger.LogInformation("Rejecting order {OrderId}", orderId);
        var result = await mediator.Send(new RejectOrderCommand(orderId, request.Reason));
        if (!result.IsSuccess) return Results.BadRequest(ApiResponse<object>.FailureResponse(result.Error!));
        return Results.Ok(ApiResponse<object>.SuccessResponse(result.Value!));
    }

    public static async Task<IResult> ConfirmOrder(
        Guid orderId,
        [FromBody] ConfirmOrderRequest request,
        [FromServices] IMediator mediator,
        [FromServices] ILogger<OrderEndpointsLogCategory> logger)
    {
        logger.LogInformation("Confirming order {OrderId}", orderId);

        var legs = request.Legs.Select(l =>
        {
            DateOnly? settlementDate = null;
            if (!string.IsNullOrWhiteSpace(l.SettlementDate) && DateOnly.TryParse(l.SettlementDate, out var sd))
                settlementDate = sd;
            return new OrderLegConfirmation(l.TransactionId, l.NAVPrice, l.Units, l.PriceType, settlementDate);
        }).ToList();

        var result = await mediator.Send(new ConfirmOrderCommand(orderId, legs));
        if (!result.IsSuccess) return Results.BadRequest(ApiResponse<object>.FailureResponse(result.Error!));
        return Results.Ok(ApiResponse<object>.SuccessResponse(result.Value!));
    }

    public static async Task<IResult> CancelOrder(
        Guid orderId,
        [FromBody] CancelTransactionRequest request,
        [FromServices] IMediator mediator,
        [FromServices] ILogger<OrderEndpointsLogCategory> logger)
    {
        logger.LogInformation("Cancelling order {OrderId}", orderId);
        var result = await mediator.Send(new CancelOrderCommand(orderId, request.Reason));
        if (!result.IsSuccess) return Results.BadRequest(ApiResponse<object>.FailureResponse(result.Error!));
        return Results.Ok(ApiResponse<object>.SuccessResponse(result.Value!));
    }
}
