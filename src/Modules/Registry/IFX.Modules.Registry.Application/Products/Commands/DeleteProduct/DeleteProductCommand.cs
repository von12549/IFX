using IFX.Modules.Registry.Application.Common;
using MediatR;

namespace IFX.Modules.Registry.Application.Products.Commands.DeleteProduct;

public record DeleteProductCommand(Guid ProductId) : IRequest<Result<bool>>;
