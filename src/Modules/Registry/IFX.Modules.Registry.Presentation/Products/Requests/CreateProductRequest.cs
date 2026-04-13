namespace IFX.Modules.Registry.Presentation.Products.Requests;

public record CreateProductRequest(
    string ProductCode,
    string ProductName,
    string ProductType,
    string BaseCurrency,
    string InceptionDate,
    string? ApirCode = null,
    string? Isin = null,
    string? RegulatorSchemeNumber = null,
    string? PdsReference = null,
    string? IssuerName = null);
