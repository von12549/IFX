namespace IFX.Platform.Context.Contracts;

public readonly record struct CorrelationId
{
    public CorrelationId(Guid value) => Value = ContextIdentifierConstants.Require(value, nameof(CorrelationId));

    public Guid Value { get; }

    public static CorrelationId New() => new(Guid.NewGuid());

    public static CorrelationId Parse(string value) => new(ContextIdentifierConstants.Parse(value, nameof(CorrelationId)));

    public static bool TryParse(string? value, out CorrelationId result)
    {
        if (ContextIdentifierConstants.TryParse(value, out var parsed))
        {
            result = new CorrelationId(parsed);
            return true;
        }

        result = default;
        return false;
    }

    public override string ToString() => ContextIdentifierConstants.Format(Value);
}

public readonly record struct OperationId
{
    public OperationId(Guid value) => Value = ContextIdentifierConstants.Require(value, nameof(OperationId));

    public Guid Value { get; }

    public static OperationId New() => new(Guid.NewGuid());

    public static OperationId Parse(string value) => new(ContextIdentifierConstants.Parse(value, nameof(OperationId)));

    public static bool TryParse(string? value, out OperationId result)
    {
        if (ContextIdentifierConstants.TryParse(value, out var parsed))
        {
            result = new OperationId(parsed);
            return true;
        }

        result = default;
        return false;
    }

    public override string ToString() => ContextIdentifierConstants.Format(Value);
}

public readonly record struct CausationId
{
    public CausationId(Guid value) => Value = ContextIdentifierConstants.Require(value, nameof(CausationId));

    public Guid Value { get; }

    public static CausationId From(OperationId operationId) => new(operationId.Value);

    public static CausationId Parse(string value) => new(ContextIdentifierConstants.Parse(value, nameof(CausationId)));

    public static bool TryParse(string? value, out CausationId result)
    {
        if (ContextIdentifierConstants.TryParse(value, out var parsed))
        {
            result = new CausationId(parsed);
            return true;
        }

        result = default;
        return false;
    }

    public override string ToString() => ContextIdentifierConstants.Format(Value);
}

public readonly record struct RequestId
{
    public RequestId(Guid value) => Value = ContextIdentifierConstants.Require(value, nameof(RequestId));

    public Guid Value { get; }

    public static RequestId New() => new(Guid.NewGuid());

    public static RequestId Parse(string value) => new(ContextIdentifierConstants.Parse(value, nameof(RequestId)));

    public static bool TryParse(string? value, out RequestId result)
    {
        if (ContextIdentifierConstants.TryParse(value, out var parsed))
        {
            result = new RequestId(parsed);
            return true;
        }

        result = default;
        return false;
    }

    public override string ToString() => ContextIdentifierConstants.Format(Value);
}

internal static class ContextIdentifierConstants
{
    public static Guid Require(Guid value, string name) =>
        value == Guid.Empty ? throw new ArgumentException($"{name} cannot be empty.", nameof(value)) : value;

    public static Guid Parse(string value, string name)
    {
        if (!TryParse(value, out var parsed))
        {
            throw new FormatException($"{name} must be a non-empty canonical GUID.");
        }

        return parsed;
    }

    public static bool TryParse(string? value, out Guid parsed) =>
        Guid.TryParseExact(value, "D", out parsed) && parsed != Guid.Empty;

    public static string Format(Guid value) => value.ToString("D");
}
