using IFX.Modules.Transaction.Presentation.Transactions.Endpoints;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;

namespace IFX.Modules.Transaction.Presentation.Extensions;

public static class EndpointExtensions
{
    public static IEndpointRouteBuilder MapTransactionEndpoints(this IEndpointRouteBuilder builder)
    {
        var group = builder.MapGroup("/api/v1").WithTags("Transactions");

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
