using IFX.Modules.Registry.Application.Common;
using IFX.Modules.Registry.Application.Products.DTOs;
using MediatR;

namespace IFX.Modules.Registry.Application.Products.Queries.GetProductById;

public record GetProductByIdQuery(Guid ProductId) : IRequest<Result<ProductDto>>;
