using IFX.BuildingBlocks.Application.Commands;
using IFX.Modules.Registry.Application.Transactions;
using IFX.Modules.Registry.Application.Common;
using MediatR;

namespace IFX.Modules.Registry.Application.Products.Commands.DeleteProduct;

public record DeleteProductCommand(Guid ProductId) : ICommand<Result<bool>, RegistryTransactionOwner>;
