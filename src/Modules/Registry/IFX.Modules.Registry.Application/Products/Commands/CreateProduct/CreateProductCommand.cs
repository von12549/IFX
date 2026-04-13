using IFX.Modules.Registry.Application.Common;
using IFX.Modules.Registry.Application.Products.DTOs;
using IFX.Modules.Registry.Domain.Enums;
using MediatR;

namespace IFX.Modules.Registry.Application.Products.Commands.CreateProduct;

public record CreateProductCommand(
    string ProductCode,
    string ProductName,
    ProductType ProductType,
    string BaseCurrency,
    DateOnly InceptionDate,
    string? ApirCode = null,
    string? Isin = null,
    string? RegulatorSchemeNumber = null,
    string? PdsReference = null,
    string? IssuerName = null) : IRequest<Result<ProductDto>>;
