using IFX.Modules.Registry.Presentation.FundClasses.Endpoints;
using IFX.Modules.Registry.Presentation.Funds.Endpoints;
using IFX.Modules.Registry.Presentation.Products.Endpoints;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.Registry.Presentation.Extensions;

public static class EndpointExtensions
{
    public static IEndpointRouteBuilder MapProductEndpoints(this IEndpointRouteBuilder builder)
    {
        var group = builder.MapGroup("/api/v1/product")
            .WithTags("Fund")
            .RequireAuthorization();

        group.MapGet("/",
            (IServiceProvider services) =>
                ProductEndpoints.GetProducts(
                    services.GetRequiredService<MediatR.IMediator>(),
                    services.GetRequiredService<ILogger<ProductEndpointsLogCategory>>()))
            .WithName("GetProducts")
            .RequirePermission("Product:list")
            .WithSummary("Get all products for the current tenant (from X-Tenant-Id header)")
            .Produces<object>(StatusCodes.Status200OK)
            .Produces<object>(StatusCodes.Status401Unauthorized);

        group.MapGet("/{productId}", ProductEndpoints.GetProductById)
            .WithName("GetProductById")
            .RequirePermission("Product:read")
            .WithSummary("Get a product by ID")
            .Produces<object>(StatusCodes.Status200OK)
            .Produces<object>(StatusCodes.Status401Unauthorized)
            .Produces<object>(StatusCodes.Status404NotFound);

        group.MapGet("/{productId}/funds",
            (Guid productId, IServiceProvider services) =>
                ProductEndpoints.GetProductFunds(
                    productId,
                    services.GetRequiredService<MediatR.IMediator>(),
                    services.GetRequiredService<ILogger<ProductEndpointsLogCategory>>()))
            .WithName("GetProductFunds")
            .RequirePermission("Product:read")
            .WithSummary("Get all funds under a product")
            .Produces<object>(StatusCodes.Status200OK)
            .Produces<object>(StatusCodes.Status401Unauthorized)
            .Produces<object>(StatusCodes.Status404NotFound);

        group.MapPost("/", ProductEndpoints.CreateProduct)
            .WithName("CreateProduct")
            .RequirePermission("Product:create")
            .WithSummary("Create a new product")
            .Produces<object>(StatusCodes.Status200OK)
            .Produces<object>(StatusCodes.Status400BadRequest)
            .Produces<object>(StatusCodes.Status401Unauthorized);

        group.MapPut("/{productId}", ProductEndpoints.UpdateProduct)
            .WithName("UpdateProduct")
            .RequirePermission("Product:update")
            .WithSummary("Update an existing product")
            .Produces<object>(StatusCodes.Status200OK)
            .Produces<object>(StatusCodes.Status400BadRequest)
            .Produces<object>(StatusCodes.Status401Unauthorized);

        group.MapDelete("/{productId}", ProductEndpoints.DeleteProduct)
            .WithName("DeleteProduct")
            .RequirePermission("Product:delete")
            .WithSummary("Close a product (soft delete)")
            .Produces<object>(StatusCodes.Status200OK)
            .Produces<object>(StatusCodes.Status400BadRequest)
            .Produces<object>(StatusCodes.Status401Unauthorized);

        return builder;
    }

    public static IEndpointRouteBuilder MapFundEndpoints(this IEndpointRouteBuilder builder)
    {
        var group = builder.MapGroup("/api/v1/fund")
            .WithTags("Fund")
            .RequireAuthorization();

        group.MapGet("/",
            (IServiceProvider services) =>
                FundEndpoints.GetFunds(
                    services.GetRequiredService<MediatR.IMediator>(),
                    services.GetRequiredService<ILogger<FundEndpointsLogCategory>>()))
            .WithName("GetFunds")
            .RequirePermission("Fund:list")
            .WithSummary("Get all funds for the current tenant (from X-Tenant-Id header)")
            .Produces<object>(StatusCodes.Status200OK)
            .Produces<object>(StatusCodes.Status401Unauthorized);

        group.MapGet("/{fundId}", FundEndpoints.GetFundById)
            .WithName("GetFundById")
            .RequirePermission("Fund:read")
            .WithSummary("Get a fund by ID")
            .Produces<object>(StatusCodes.Status200OK)
            .Produces<object>(StatusCodes.Status401Unauthorized)
            .Produces<object>(StatusCodes.Status404NotFound);

        group.MapPost("/", FundEndpoints.CreateFund)
            .WithName("CreateFund")
            .RequirePermission("Fund:create")
            .WithSummary("Create a new fund")
            .Produces<object>(StatusCodes.Status200OK)
            .Produces<object>(StatusCodes.Status400BadRequest)
            .Produces<object>(StatusCodes.Status401Unauthorized);

        group.MapPut("/{fundId}", FundEndpoints.UpdateFund)
            .WithName("UpdateFund")
            .RequirePermission("Fund:update")
            .WithSummary("Update an existing fund")
            .Produces<object>(StatusCodes.Status200OK)
            .Produces<object>(StatusCodes.Status400BadRequest)
            .Produces<object>(StatusCodes.Status401Unauthorized);

        group.MapDelete("/{fundId}", FundEndpoints.DeleteFund)
            .WithName("DeleteFund")
            .RequirePermission("Fund:delete")
            .WithSummary("Close a fund (soft delete)")
            .Produces<object>(StatusCodes.Status200OK)
            .Produces<object>(StatusCodes.Status400BadRequest)
            .Produces<object>(StatusCodes.Status401Unauthorized);

        return builder;
    }

    public static IEndpointRouteBuilder MapFundClassEndpoints(this IEndpointRouteBuilder builder)
    {
        var group = builder.MapGroup("/api/v1/fund/{fundId}/class")
            .WithTags("FundClass")
            .RequireAuthorization();

        group.MapGet("/",
            (Guid fundId, IServiceProvider services) =>
                FundClassEndpoints.GetClasses(
                    fundId,
                    services.GetRequiredService<MediatR.IMediator>(),
                    services.GetRequiredService<ILogger<FundClassEndpointsLogCategory>>()))
            .WithName("GetClasses")
            .RequirePermission("FundClass:list")
            .WithSummary("Get all classes for a fund")
            .Produces<object>(StatusCodes.Status200OK)
            .Produces<object>(StatusCodes.Status401Unauthorized);

        group.MapGet("/{classId}", FundClassEndpoints.GetClassById)
            .WithName("GetClassById")
            .RequirePermission("FundClass:read")
            .WithSummary("Get a fund class by ID")
            .Produces<object>(StatusCodes.Status200OK)
            .Produces<object>(StatusCodes.Status401Unauthorized)
            .Produces<object>(StatusCodes.Status404NotFound);

        group.MapPost("/", FundClassEndpoints.CreateClass)
            .WithName("CreateClass")
            .RequirePermission("FundClass:create")
            .WithSummary("Create a new fund class")
            .Produces<object>(StatusCodes.Status200OK)
            .Produces<object>(StatusCodes.Status400BadRequest)
            .Produces<object>(StatusCodes.Status401Unauthorized);

        group.MapPut("/{classId}", FundClassEndpoints.UpdateClass)
            .WithName("UpdateClass")
            .RequirePermission("FundClass:update")
            .WithSummary("Update an existing fund class")
            .Produces<object>(StatusCodes.Status200OK)
            .Produces<object>(StatusCodes.Status400BadRequest)
            .Produces<object>(StatusCodes.Status401Unauthorized);

        group.MapDelete("/{classId}", FundClassEndpoints.DeleteClass)
            .WithName("DeleteClass")
            .RequirePermission("FundClass:delete")
            .WithSummary("Close a fund class (soft delete)")
            .Produces<object>(StatusCodes.Status200OK)
            .Produces<object>(StatusCodes.Status400BadRequest)
            .Produces<object>(StatusCodes.Status401Unauthorized);

        return builder;
    }
}
