namespace IFX.Modules.Registry.Presentation.Products.Requests;

public record UpdateProductRequest(
    string ProductName,
    string? ApirCode,
    string? Isin,
    string? RegulatorSchemeNumber,
    string? PdsReference,
    string? IssuerName,
    string? WindUpDate);
