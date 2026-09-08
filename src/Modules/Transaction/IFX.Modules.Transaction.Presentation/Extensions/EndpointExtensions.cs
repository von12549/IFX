using IFX.Modules.Transaction.Presentation.Orders.Endpoints;
using IFX.Modules.Transaction.Presentation.Transactions.Endpoints;
using IFX.BuildingBlocks.Application.Context;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;

namespace IFX.Modules.Transaction.Presentation.Extensions;

public static class EndpointExtensions
{
    public static IEndpointRouteBuilder MapTransactionEndpoints(this IEndpointRouteBuilder builder)
    {
        // Order endpoints
        var orderGroup = builder.MapGroup("/api/v1")
            .WithTags("Orders")
            .WithMetadata(ExecutionScopeRequirement.Tenant);

        orderGroup.MapGet("/order", OrderEndpoints.GetOrders)
            .RequireAuthorization()
            .RequirePermission("Order:list");

        orderGroup.MapGet("/order/{orderId:guid}", OrderEndpoints.GetOrderById)
            .RequireAuthorization()
            .RequirePermission("Order:read");

        orderGroup.MapPost("/order", OrderEndpoints.CreateOrder)
            .RequireAuthorization()
            .RequirePermission("Order:create");

        orderGroup.MapPost("/order/{orderId:guid}/accept", OrderEndpoints.AcceptOrder)
            .RequireAuthorization()
            .RequirePermission("Order:update");

        orderGroup.MapPost("/order/{orderId:guid}/reject", OrderEndpoints.RejectOrder)
            .RequireAuthorization()
            .RequirePermission("Order:update");

        orderGroup.MapPost("/order/{orderId:guid}/confirm", OrderEndpoints.ConfirmOrder)
            .RequireAuthorization()
            .RequirePermission("Order:update");

        orderGroup.MapDelete("/order/{orderId:guid}", OrderEndpoints.CancelOrder)
            .RequireAuthorization()
            .RequirePermission("Order:delete");

        // Transaction endpoints (backward compatible)
        var group = builder.MapGroup("/api/v1")
            .WithTags("Transactions")
            .WithMetadata(ExecutionScopeRequirement.Tenant);

        group.MapGet("/transaction", TransactionEndpoints.GetTransactions)
            .RequireAuthorization()
            .RequirePermission("Transaction:list");

        group.MapGet("/transaction/{transactionId:guid}", TransactionEndpoints.GetTransactionById)
            .RequireAuthorization()
            .RequirePermission("Transaction:read");

        group.MapPost("/transaction/subscription", TransactionEndpoints.CreateSubscription)
            .RequireAuthorization()
            .RequirePermission("Transaction:create");

        group.MapPost("/transaction/redemption", TransactionEndpoints.CreateRedemption)
            .RequireAuthorization()
            .RequirePermission("Transaction:create");

        group.MapPost("/transaction/transfer", TransactionEndpoints.CreateTransfer)
            .RequireAuthorization()
            .RequirePermission("Transaction:create");

        group.MapPost("/transaction/switch", TransactionEndpoints.CreateSwitch)
            .RequireAuthorization()
            .RequirePermission("Transaction:create");

        group.MapPost("/transaction/{transactionId:guid}/process", TransactionEndpoints.ProcessTransaction)
            .RequireAuthorization()
            .RequirePermission("Transaction:process");

        group.MapPost("/transaction/{transactionId:guid}/cancel", TransactionEndpoints.CancelTransaction)
            .RequireAuthorization()
            .RequirePermission("Transaction:cancel");

        return builder;
    }
}
