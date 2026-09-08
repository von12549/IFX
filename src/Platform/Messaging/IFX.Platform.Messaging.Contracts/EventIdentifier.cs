namespace IFX.Platform.Messaging.Contracts;

public readonly record struct EventIdentifier
{
    public EventIdentifier(Guid value)
    {
        Value = value == Guid.Empty
            ? throw new ArgumentException("EventId cannot be empty.", nameof(value))
            : value;
    }

    public Guid Value { get; }

    public static EventIdentifier New() => new(Guid.NewGuid());

    public static EventIdentifier Parse(string value)
    {
        if (!TryParse(value, out var result))
        {
            throw new FormatException("EventId must be a non-empty canonical GUID.");
        }

        return result;
    }

    public static bool TryParse(string? value, out EventIdentifier result)
    {
        if (Guid.TryParseExact(value, "D", out var parsed) && parsed != Guid.Empty)
        {
            result = new EventIdentifier(parsed);
            return true;
        }

        result = default;
        return false;
    }

    public override string ToString() => Value.ToString("D");
}
