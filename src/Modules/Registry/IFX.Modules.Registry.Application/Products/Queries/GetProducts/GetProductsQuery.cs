using IFX.Modules.Registry.Application.Common;
using IFX.Modules.Registry.Application.Products.DTOs;
using MediatR;

namespace IFX.Modules.Registry.Application.Products.Queries.GetProducts;

public record GetProductsQuery() : IRequest<Result<List<ProductDto>>>;
