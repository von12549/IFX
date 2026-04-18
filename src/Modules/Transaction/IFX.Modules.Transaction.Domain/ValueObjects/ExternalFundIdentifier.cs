namespace IFX.Modules.Transaction.Domain.ValueObjects;

public class ExternalFundIdentifier
{
    public static readonly HashSet<string> SupportedTypes = new(StringComparer.OrdinalIgnoreCase)
        { "ISIN", "SEDOL", "APIR", "CUSIP", "OTHER" };

    public string Type { get; private set; } = string.Empty;
    public string Identifier { get; private set; } = string.Empty;
    public string? OtherType { get; private set; }

    private ExternalFundIdentifier() { }

    public static ExternalFundIdentifier Create(string type, string identifier, string? otherType = null)
    {
        if (string.IsNullOrWhiteSpace(type) || !SupportedTypes.Contains(type))
            throw new ArgumentException($"Fund identifier type must be one of: {string.Join(", ", SupportedTypes)}.", nameof(type));
        if (string.IsNullOrWhiteSpace(identifier))
            throw new ArgumentException("Fund identifier value is required.", nameof(identifier));
        if (type.Equals("OTHER", StringComparison.OrdinalIgnoreCase) && string.IsNullOrWhiteSpace(otherType))
            throw new ArgumentException("OtherType is required when Type = OTHER.", nameof(otherType));

        return new ExternalFundIdentifier { Type = type.ToUpperInvariant(), Identifier = identifier, OtherType = otherType };
    }
}
