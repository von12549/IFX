namespace IFX.Modules.Transaction.Domain.ValueObjects;

public class DealingPriceDetails
{
    public string PriceType { get; private set; } = string.Empty;
    public decimal Amount { get; private set; }
    public string Currency { get; private set; } = string.Empty;

    private DealingPriceDetails() { }

    public static DealingPriceDetails Create(string priceType, decimal amount, string currency)
    {
        if (string.IsNullOrWhiteSpace(priceType))
            throw new ArgumentException("Price type is required.", nameof(priceType));
        if (amount <= 0)
            throw new ArgumentException("Price amount must be positive.", nameof(amount));
        if (string.IsNullOrWhiteSpace(currency) || currency.Length != 3)
            throw new ArgumentException("Currency must be a 3-letter ISO code.", nameof(currency));

        return new DealingPriceDetails { PriceType = priceType, Amount = amount, Currency = currency.ToUpperInvariant() };
    }
}
