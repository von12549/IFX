using IFX.Modules.Registry.Application.Products.Commands.CreateProduct;
using IFX.Modules.Registry.Application.Products.Commands.DeleteProduct;
using IFX.Modules.Registry.Application.Products.Commands.UpdateProduct;
using IFX.Modules.Registry.Application.Products.Queries.GetProductById;
using IFX.Modules.Registry.Application.Products.Queries.GetProductFunds;
using IFX.Modules.Registry.Application.Products.Queries.GetProducts;
using IFX.Modules.Registry.Domain.Enums;
using IFX.Modules.Registry.Presentation.Models.Responses;
using IFX.Modules.Registry.Presentation.Products.Requests;
using MediatR;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.Registry.Presentation.Products.Endpoints;

public sealed class ProductEndpointsLogCategory { }

public static class ProductEndpoints
{
    public static async Task<IResult> GetProducts(
        [FromServices] IMediator mediator,
        [FromServices] ILogger<ProductEndpointsLogCategory> logger)
    {
        logger.LogInformation("Accessing products list");

        var result = await mediator.Send(new GetProductsQuery());

        if (!result.IsSuccess)
            return Results.BadRequest(ApiResponse<object>.FailureResponse(result.Error!));

        return Results.Ok(ApiResponse<object>.SuccessResponse(result.Value!));
    }

    public static async Task<IResult> GetProductById(
        Guid productId,
        [FromServices] IMediator mediator,
        [FromServices] ILogger<ProductEndpointsLogCategory> logger)
    {
        logger.LogInformation("Getting product: {ProductId}", productId);

        var result = await mediator.Send(new GetProductByIdQuery(productId));

        if (!result.IsSuccess)
            return Results.NotFound(ApiResponse<object>.FailureResponse(result.Error!));

        return Results.Ok(ApiResponse<object>.SuccessResponse(result.Value!));
    }

    public static async Task<IResult> GetProductFunds(
        Guid productId,
        [FromServices] IMediator mediator,
        [FromServices] ILogger<ProductEndpointsLogCategory> logger)
    {
        logger.LogInformation("Getting funds for product: {ProductId}", productId);

        var result = await mediator.Send(new GetProductFundsQuery(productId));

        if (!result.IsSuccess)
            return Results.NotFound(ApiResponse<object>.FailureResponse(result.Error!));

        return Results.Ok(ApiResponse<object>.SuccessResponse(result.Value!));
    }

    public static async Task<IResult> CreateProduct(
        [FromBody] CreateProductRequest request,
        [FromServices] IMediator mediator,
        [FromServices] ILogger<ProductEndpointsLogCategory> logger)
    {
        logger.LogInformation("Creating product: {ProductCode}", request.ProductCode);

        if (!Enum.TryParse<ProductType>(request.ProductType, ignoreCase: true, out var productType))
            return Results.BadRequest(ApiResponse<object>.FailureResponse($"Invalid product type: {request.ProductType}"));

        if (!DateOnly.TryParse(request.InceptionDate, out var inceptionDate))
            return Results.BadRequest(ApiResponse<object>.FailureResponse($"Invalid inception date: {request.InceptionDate}"));

        var result = await mediator.Send(new CreateProductCommand(
            request.ProductCode,
            request.ProductName,
            productType,
            request.BaseCurrency,
            inceptionDate,
            request.ApirCode,
            request.Isin,
            request.RegulatorSchemeNumber,
            request.PdsReference,
            request.IssuerName));

        if (!result.IsSuccess)
            return Results.BadRequest(ApiResponse<object>.FailureResponse(result.Error!));

        return Results.Ok(ApiResponse<object>.SuccessResponse(result.Value!));
    }

    public static async Task<IResult> UpdateProduct(
        Guid productId,
        [FromBody] UpdateProductRequest request,
        [FromServices] IMediator mediator,
        [FromServices] ILogger<ProductEndpointsLogCategory> logger)
    {
        logger.LogInformation("Updating product: {ProductId}", productId);

        DateOnly? windUpDate = null;
        if (request.WindUpDate != null)
        {
            if (!DateOnly.TryParse(request.WindUpDate, out var parsed))
                return Results.BadRequest(ApiResponse<object>.FailureResponse($"Invalid wind-up date: {request.WindUpDate}"));
            windUpDate = parsed;
        }

        var result = await mediator.Send(new UpdateProductCommand(
            productId,
            request.ProductName,
            request.ApirCode,
            request.Isin,
            request.RegulatorSchemeNumber,
            request.PdsReference,
            request.IssuerName,
            windUpDate));

        if (!result.IsSuccess)
            return Results.BadRequest(ApiResponse<object>.FailureResponse(result.Error!));

        return Results.Ok(ApiResponse<object>.SuccessResponse(result.Value!));
    }

    public static async Task<IResult> DeleteProduct(
        Guid productId,
        [FromServices] IMediator mediator,
        [FromServices] ILogger<ProductEndpointsLogCategory> logger)
    {
        logger.LogInformation("Closing product: {ProductId}", productId);

        var result = await mediator.Send(new DeleteProductCommand(productId));

        if (!result.IsSuccess)
            return Results.BadRequest(ApiResponse<object>.FailureResponse(result.Error!));

        return Results.Ok(ApiResponse<object>.SuccessResponse(result.Value!));
    }
}
