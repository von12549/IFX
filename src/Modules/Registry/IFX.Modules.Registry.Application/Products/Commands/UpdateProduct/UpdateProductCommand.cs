using IFX.BuildingBlocks.Application.Commands;
using IFX.Modules.Registry.Application.Transactions;
using IFX.Modules.Registry.Application.Common;
using IFX.Modules.Registry.Application.Products.DTOs;
using MediatR;

namespace IFX.Modules.Registry.Application.Products.Commands.UpdateProduct;

public record UpdateProductCommand(
    Guid ProductId,
    string ProductName,
    string? ApirCode,
    string? Isin,
    string? RegulatorSchemeNumber,
    string? PdsReference,
    string? IssuerName,
    DateOnly? WindUpDate) : ICommand<Result<ProductDto>, RegistryTransactionOwner>;
